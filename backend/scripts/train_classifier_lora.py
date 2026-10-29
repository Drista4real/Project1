"""Fine-tune Model 1 with LoRA on a verified frozen classifier dataset bundle."""

# ruff: noqa: E402
import argparse
import gc
import json
import math
import sys
from dataclasses import asdict, dataclass
from importlib.metadata import version
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "backend") not in sys.path:
    sys.path.insert(0, str(ROOT / "backend"))

import torch
from sklearn.metrics import accuracy_score, classification_report, f1_score
from torch.utils.data import DataLoader
from transformers import (
    AutoModelForSequenceClassification,
    AutoTokenizer,
    DataCollatorWithPadding,
    get_linear_schedule_with_warmup,
    set_seed,
)

from app.infrastructure.ai.classifier.config import CATEGORIES, CONFIDENCE_THRESHOLD
from app.infrastructure.ai.classifier.lora import LoRAClassifier, select_device
from app.infrastructure.ai.classifier.phobert_embedder import preprocess_text
from scripts.dataset_pipeline import Taxonomy, verify_bundle


@dataclass(frozen=True)
class TrainOptions:
    """T4-oriented defaults; CPU is available explicitly for small checks."""

    model_name: str = "vinai/phobert-base-v2"
    revision: str = "main"
    device: str = "cuda"
    epochs: int = 5
    batch_size: int = 8
    gradient_accumulation: int = 4
    learning_rate: float = 2e-4
    max_length: int = 128
    rank: int = 8
    alpha: int = 16
    dropout: float = 0.1
    seed: int = 42
    fp16: bool = True
    local_files_only: bool = False

    def validate(self) -> None:
        """Reject invalid settings before loading a model or creating outputs."""
        for value in (
            self.epochs,
            self.batch_size,
            self.gradient_accumulation,
            self.rank,
            self.alpha,
        ):
            if value < 1:
                raise ValueError("Epochs, batch sizes, rank and alpha must be positive")
        if (
            not 2 <= self.max_length <= 256
            or not math.isfinite(self.learning_rate)
            or self.learning_rate <= 0
            or not 0 <= self.dropout < 1
        ):
            raise ValueError("Invalid max length, learning rate or dropout")


def write_json(path: Path, payload: object) -> None:
    """Persist portable metadata, rejecting NaN/Infinity in reports."""
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def make_loader(rows, tokenizer, labels, options, *, shuffle=False):
    """Segment before tokenization and dynamically pad without changing splits."""
    encoded = tokenizer(
        [preprocess_text(row["text"]) for row in rows],
        truncation=True,
        max_length=options.max_length,
        return_token_type_ids=False,
    )
    features = [
        {
            **{key: values[i] for key, values in encoded.items()},
            "labels": labels.index(row["category"]),
        }
        for i, row in enumerate(rows)
    ]
    return DataLoader(
        features,
        batch_size=options.batch_size,
        shuffle=shuffle,
        num_workers=0,
        collate_fn=DataCollatorWithPadding(tokenizer, pad_to_multiple_of=8),
        generator=torch.Generator().manual_seed(options.seed),
    )


def evaluate(model, loader, device, labels):
    """Compute aggregate metrics without persisting financial descriptions."""
    model.eval()
    actual, predicted, confidences = [], [], []
    with torch.inference_mode():
        for batch in loader:
            actual.extend(batch.pop("labels").tolist())
            inputs = {key: value.to(device) for key, value in batch.items()}
            probabilities = model(**inputs).logits.float().softmax(dim=-1)
            if not torch.isfinite(probabilities).all():
                raise RuntimeError("Non-finite evaluation probabilities")
            scores, indices = probabilities.max(dim=-1)
            predicted.extend(indices.cpu().tolist())
            confidences.extend(scores.cpu().tolist())
    return {
        "rows": len(actual),
        "macro_f1": float(
            f1_score(actual, predicted, average="macro", zero_division=0)
        ),
        "accuracy": float(accuracy_score(actual, predicted)),
        "local_handling_rate": sum(c >= CONFIDENCE_THRESHOLD for c in confidences)
        / len(confidences),
        "classification_report": classification_report(
            actual,
            predicted,
            labels=list(range(len(labels))),
            target_names=labels,
            output_dict=True,
            zero_division=0,
        ),
    }


def train(dataset_dir: Path, output_dir: Path, cache_dir: Path, options: TrainOptions):
    """Select on validation only, then reload the saved best adapter and test once."""
    options.validate()
    device = select_device(options.device)
    splits = verify_bundle(dataset_dir)
    labels = sorted(CATEGORIES)
    if set(Taxonomy.load(dataset_dir / "taxonomy.json").labels) != set(labels):
        raise ValueError("LoRA training requires the six agreed expense categories")
    if output_dir.exists() and any(output_dir.iterdir()):
        raise ValueError("Output directory is not empty; choose a new run directory")

    from peft import LoraConfig, TaskType, get_peft_model

    set_seed(options.seed)
    tokenizer = AutoTokenizer.from_pretrained(
        options.model_name,
        revision=options.revision,
        cache_dir=str(cache_dir),
        local_files_only=options.local_files_only,
        use_fast=False,
    )
    base = AutoModelForSequenceClassification.from_pretrained(
        options.model_name,
        revision=options.revision,
        num_labels=len(labels),
        id2label=dict(enumerate(labels)),
        label2id={label: i for i, label in enumerate(labels)},
        cache_dir=str(cache_dir),
        local_files_only=options.local_files_only,
    )
    resolved_revision = getattr(base.config, "_commit_hash", None) or options.revision
    model = get_peft_model(
        base,
        LoraConfig(
            task_type=TaskType.SEQ_CLS,
            r=options.rank,
            lora_alpha=options.alpha,
            lora_dropout=options.dropout,
            target_modules=["query", "value"],
            modules_to_save=["classifier"],
            bias="none",
        ),
    ).to(device)
    model.print_trainable_parameters()
    train_loader = make_loader(
        splits["train"], tokenizer, labels, options, shuffle=True
    )
    validation_loader = make_loader(splits["validation"], tokenizer, labels, options)
    optimizer = torch.optim.AdamW(
        (p for p in model.parameters() if p.requires_grad),
        lr=options.learning_rate,
        weight_decay=0.01,
    )
    total_steps = (
        math.ceil(len(train_loader) / options.gradient_accumulation) * options.epochs
    )
    scheduler = get_linear_schedule_with_warmup(
        optimizer,
        num_warmup_steps=int(total_steps * 0.1),
        num_training_steps=total_steps,
    )
    mixed_precision = options.fp16 and device.type == "cuda"
    scaler = torch.amp.GradScaler("cuda", enabled=mixed_precision)
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((dataset_dir / "manifest.json").read_text(encoding="utf-8"))
    write_json(output_dir / "training_data_manifest.json", manifest)
    write_json(
        output_dir / "lora_config.json",
        {
            "schema_version": 1,
            "base_model": options.model_name,
            "base_revision": resolved_revision,
            "labels": labels,
            "preprocessing": "lower_whitespace_underthesea_text_v1",
            "max_length": options.max_length,
            "confidence_threshold": CONFIDENCE_THRESHOLD,
        },
    )
    write_json(
        output_dir / "training_config.json",
        {
            **asdict(options),
            "effective_fp16": mixed_precision,
            "versions": {
                p: version(p) for p in ("torch", "transformers", "peft", "underthesea")
            },
        },
    )
    tokenizer.save_pretrained(output_dir)
    best_score, best_epoch, history = -1.0, 0, []
    for epoch in range(1, options.epochs + 1):
        model.train()
        optimizer.zero_grad(set_to_none=True)
        total_loss = 0.0
        for step, batch in enumerate(train_loader):
            batch = {key: value.to(device) for key, value in batch.items()}
            group_start = (
                step // options.gradient_accumulation
            ) * options.gradient_accumulation
            group_rows = min(
                options.gradient_accumulation * options.batch_size,
                len(train_loader.dataset) - group_start * options.batch_size,
            )
            with torch.autocast(
                device.type, dtype=torch.float16, enabled=mixed_precision
            ):
                loss = model(**batch).loss
            if not torch.isfinite(loss):
                raise RuntimeError("Non-finite training loss; retry with --no-fp16")
            batch_rows = batch["labels"].shape[0]
            total_loss += float(loss.detach()) * batch_rows
            scaler.scale(loss * batch_rows / group_rows).backward()
            if (step + 1) % options.gradient_accumulation == 0 or step + 1 == len(
                train_loader
            ):
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
                old_scale = scaler.get_scale()
                scaler.step(optimizer)
                scaler.update()
                if scaler.get_scale() >= old_scale:
                    scheduler.step()
                optimizer.zero_grad(set_to_none=True)
        metrics = evaluate(model, validation_loader, device, labels)
        history.append(
            {
                "epoch": epoch,
                "train_loss": total_loss / len(train_loader.dataset),
                "validation": metrics,
            }
        )
        print(
            f"Epoch {epoch}/{options.epochs}: "
            f"validation macro F1={metrics['macro_f1']:.4f}",
            flush=True,
        )
        if metrics["macro_f1"] > best_score:
            best_score, best_epoch = metrics["macro_f1"], epoch
            model.save_pretrained(output_dir, safe_serialization=True)
        write_json(output_dir / "history.json", history)

    # Free training state before reloading the exact exported adapter for final testing.
    del model, base, optimizer, scheduler, scaler, loss, batch
    gc.collect()
    if device.type == "cuda":
        torch.cuda.empty_cache()
    restored = LoRAClassifier(
        output_dir,
        device=options.device,
        cache_dir=cache_dir,
        local_files_only=options.local_files_only,
    )
    test_loader = make_loader(splits["test"], restored.tokenizer, labels, options)
    report = {
        "dataset_id": manifest["dataset_id"],
        "evaluation_scope": manifest.get("evaluation_scope"),
        "best_epoch": best_epoch,
        "best_validation_macro_f1": best_score,
        "test": evaluate(restored.model, test_loader, device, labels),
    }
    write_json(output_dir / "metrics.json", report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return report


def main() -> None:
    """CLI entry point shared with the Colab notebook."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument(
        "--cache-dir", type=Path, default=ROOT / "weights/cache/phobert-lora"
    )
    defaults = TrainOptions()
    for name in (
        "model_name",
        "revision",
        "device",
        "epochs",
        "batch_size",
        "gradient_accumulation",
        "learning_rate",
        "max_length",
        "rank",
        "alpha",
        "dropout",
        "seed",
    ):
        value = getattr(defaults, name)
        parser.add_argument(
            "--" + name.replace("_", "-"), type=type(value), default=value
        )
    parser.add_argument("--no-fp16", action="store_true")
    parser.add_argument("--local-files-only", action="store_true")
    args = vars(parser.parse_args())
    dataset_dir, output_dir, cache_dir = (
        args.pop(name) for name in ("dataset_dir", "output_dir", "cache_dir")
    )
    args["fp16"] = not args.pop("no_fp16")
    try:
        train(dataset_dir, output_dir, cache_dir, TrainOptions(**args))
    except (OSError, ValueError, RuntimeError, ImportError, KeyError) as error:
        parser.exit(1, f"LoRA training failed: {error}\n")


if __name__ == "__main__":
    main()
