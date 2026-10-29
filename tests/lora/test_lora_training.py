"""Exercise real PEFT optimization and artifact reload offline on tiny RoBERTa."""

import csv
import json
import os
import random
import subprocess
import sys
from dataclasses import replace
from pathlib import Path

import pytest
import torch
from safetensors.torch import load_file
from transformers import BertTokenizer, RobertaConfig, RobertaForSequenceClassification

pytest.importorskip("peft")

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))

from app.infrastructure.ai.classifier.config import CATEGORIES  # noqa: E402
from app.infrastructure.ai.classifier.lora import (  # noqa: E402
    LoRAClassifier,
    select_device,
)
from scripts import train_classifier_lora as training  # noqa: E402
from scripts.dataset_pipeline import Source, prepare_dataset, verify_bundle  # noqa: E402


@pytest.fixture
def inputs(tmp_path):
    """Build a real frozen six-class bundle and a local tiny model/tokenizer."""
    generator = random.Random(123)
    data = tmp_path / "source.csv"
    with data.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["text", "category"])
        writer.writeheader()
        for label in CATEGORIES:
            for _ in range(14):
                name = "".join(generator.choices("abcdefghijklmnopqrstuvwxyz", k=18))
                writer.writerow({"text": name + " 35k", "category": label})
    bundle = tmp_path / "bundle"
    prepare_dataset(
        [Source(data, "fixture", "synthetic", "test fixture")],
        ROOT / "data/taxonomy/expense_categories.v2_defaults.json",
        bundle,
        ambiguity_policy="quarantine",
    )
    base_dir = tmp_path / "base"
    base_dir.mkdir()
    vocab = ["[PAD]", "[UNK]", "[CLS]", "[SEP]", "[MASK]", "35", "k"]
    (base_dir / "vocab.txt").write_text("\n".join(vocab), encoding="utf-8")
    tokenizer = BertTokenizer(vocab_file=str(base_dir / "vocab.txt"))
    tokenizer.save_pretrained(base_dir)
    config = RobertaConfig(
        vocab_size=len(vocab),
        hidden_size=16,
        intermediate_size=24,
        num_hidden_layers=1,
        num_attention_heads=2,
        num_labels=6,
        max_position_embeddings=258,
        pad_token_id=0,
        hidden_dropout_prob=0,
        attention_probs_dropout_prob=0,
    )
    base = RobertaForSequenceClassification(config)
    base.save_pretrained(base_dir)
    options = training.TrainOptions(
        model_name=str(base_dir),
        device="cpu",
        epochs=2,
        batch_size=7,
        gradient_accumulation=3,
        max_length=32,
        learning_rate=0.01,
        local_files_only=True,
        dropout=0,
    )
    return bundle, base_dir, options


def test_real_training_selection_reload_and_head(tmp_path, inputs, monkeypatch):
    """Optimize adapter/head only; test once after validation selection and reload."""
    bundle, base_dir, options = inputs
    splits = verify_bundle(bundle)
    before = (bundle / "manifest.json").read_bytes()
    eval_calls = []
    best_weights = {}
    evaluate = training.evaluate
    test_record_texts = {row["text"] for row in splits["test"]}
    tokenize = training.make_loader
    fitted = {}

    def recording_loader(rows, *args, **kwargs):
        if test_record_texts.intersection(row["text"] for row in rows):
            # The test split must not even be tokenized until all epochs finish.
            assert len(eval_calls) == options.epochs
        return tokenize(rows, *args, **kwargs)

    def recording_evaluate(model, loader, device, labels):
        if len(eval_calls) < options.epochs:
            trainable = [
                name for name, p in model.named_parameters() if p.requires_grad
            ]
            assert trainable
            assert all(
                "lora_" in name or "modules_to_save" in name for name in trainable
            )
            if not fitted:
                fitted.update(model.base_model.model.roberta.state_dict())
        result = evaluate(model, loader, device, labels)
        eval_calls.append(result["rows"])
        if len(eval_calls) <= options.epochs:
            # Force epoch 1 to win even though epoch 2 still updates parameters.
            result["macro_f1"] = 0.9 if len(eval_calls) == 1 else 0.1
            if len(eval_calls) == 1:
                from peft import get_peft_model_state_dict

                best_weights.update(
                    {
                        name: value.detach().cpu().clone()
                        for name, value in get_peft_model_state_dict(model).items()
                    }
                )
        return result

    monkeypatch.setattr(training, "make_loader", recording_loader)
    monkeypatch.setattr(training, "evaluate", recording_evaluate)
    old_threads = torch.get_num_threads()
    torch.set_num_threads(1)
    try:
        output = tmp_path / "output"
        report = training.train(bundle, output, tmp_path / "cache", options)
        assert report["best_epoch"] == 1
        assert report["best_validation_macro_f1"] == 0.9
        assert eval_calls == [len(splits["validation"])] * 2 + [len(splits["test"])]
        assert (bundle / "manifest.json").read_bytes() == before
        assert (
            json.loads(
                (output / "training_data_manifest.json").read_text(encoding="utf-8")
            )["dataset_id"]
            == report["dataset_id"]
        )
        weights = load_file(output / "adapter_model.safetensors")
        assert set(weights) == set(best_weights)
        assert all(
            torch.equal(weights[name], value) for name, value in best_weights.items()
        )
        assert any("classifier" in name for name in weights)
        assert any(
            "lora_B" in name and tensor.abs().sum() > 0
            for name, tensor in weights.items()
        )
        original = RobertaForSequenceClassification.from_pretrained(base_dir)
        # Ordinary base weights are frozen, not accidentally fully fine-tuned.
        for name, value in original.roberta.state_dict().items():
            if "query" not in name and "value" not in name:
                assert torch.equal(value, fitted[name])
        first = LoRAClassifier(output, local_files_only=True)
        second = LoRAClassifier(output, local_files_only=True)
        assert first.predict("an trua 40k") == second.predict("an trua 40k")
        result = first.predict("an trua 40k")
        classification = first.classify("an trua 40k")
        assert classification.label == result["category"]
        assert classification.confidence == result["confidence"]
        assert result["category"] in CATEGORIES
        assert 0 <= result["confidence"] <= 1
        assert result["source"] in ("LOCAL", "CLOUD_FALLBACK")
        with pytest.raises(ValueError, match="empty"):
            first.predict("  ")
        config = json.loads((output / "lora_config.json").read_text(encoding="utf-8"))
        config["labels"].reverse()
        training.write_json(output / "lora_config.json", config)
        with pytest.raises(ValueError, match="metadata"):
            LoRAClassifier(output, local_files_only=True)
    finally:
        torch.set_num_threads(old_threads)


def test_tampered_bundle_and_existing_output_rejected(tmp_path, inputs):
    """Fail before loading a model; never overwrite an existing trained run."""
    bundle, _, options = inputs
    output = tmp_path / "output"
    output.mkdir()
    (output / "keep.txt").write_text("keep")
    with pytest.raises(ValueError, match="not empty"):
        training.train(bundle, output, tmp_path / "cache", options)
    assert (output / "keep.txt").read_text() == "keep"
    with (bundle / "train.csv").open("a", encoding="utf-8") as stream:
        stream.write("tampered")
    with pytest.raises(ValueError, match="hash mismatch"):
        training.train(bundle, tmp_path / "new", tmp_path / "cache", options)
    assert not (tmp_path / "new").exists()


@pytest.mark.parametrize(
    "changes",
    [
        {"epochs": 0},
        {"batch_size": 0},
        {"gradient_accumulation": 0},
        {"learning_rate": float("nan")},
        {"max_length": 257},
        {"dropout": 1.0},
    ],
)
def test_invalid_options(changes):
    with pytest.raises(ValueError):
        replace(training.TrainOptions(), **changes).validate()


def test_no_gpu_fails_explicitly(monkeypatch):
    monkeypatch.setattr(torch.cuda, "is_available", lambda: False)
    with pytest.raises(ValueError, match="T4"):
        select_device("cuda")
    assert select_device("cpu").type == "cpu"


def test_notebook_model1_only_runs_cli_without_balance_data(
    tmp_path, inputs, monkeypatch
):
    """Run the actual notebook data/train cells and both CLIs on a tiny CPU model."""
    bundle, base_dir, _ = inputs
    notebook = json.loads(
        (ROOT / "notebooks/project1_colab.ipynb").read_text(encoding="utf-8")
    )
    cells = {cell["id"]: "".join(cell["source"]) for cell in notebook["cells"]}
    monkeypatch.setenv("OMP_NUM_THREADS", "1")
    monkeypatch.setenv("MKL_NUM_THREADS", "1")

    def use_cpu(command):
        # Exercise notebook commands unchanged except unavailable GPU hardware.
        command = list(command)
        if "--device" in command:
            command[command.index("--device") + 1] = "cpu"
        return command

    class CPUProcesses:
        PIPE = subprocess.PIPE
        STDOUT = subprocess.STDOUT

        @staticmethod
        def Popen(command, **kwargs):
            return subprocess.Popen(use_cpu(command), **kwargs)

        @staticmethod
        def run(command, **kwargs):
            return subprocess.run(use_cpu(command), **kwargs)

    run_dir = tmp_path / "notebook-run"
    run_dir.mkdir()
    context = dict(
        Path=Path,
        os=os,
        sys=sys,
        subprocess=CPUProcesses,
        REPO_DIR=ROOT,
        RUN_DIR=run_dir,
        DATASET_DIR=bundle,
        RUN_LORA=True,
        RUN_CLASSIFIER=False,
        RUN_FORECASTER=False,
        LORA_CACHE_DIR=tmp_path / "cache",
        LORA_MODEL=str(base_dir),
        LORA_REVISION="main",
        LORA_EPOCHS=1,
        LORA_BATCH_SIZE=16,
        LORA_GRADIENT_ACCUMULATION=2,
        LORA_MAX_LENGTH=32,
        LORA_LEARNING_RATE=0.01,
    )
    # No FORECAST_CSV or run_python: accessing Model 2 would fail this test.
    exec(cells["project1-10"], context)
    exec(cells["project1-12"], context)
    assert context["CLASSIFIER_READY"]
    assert (run_dir / "classifier_lora/metrics.json").is_file()
    assert "Epoch 1/1" in (run_dir / "classifier_lora.log").read_text(encoding="utf-8")
    assert not (run_dir / "forecaster").exists()
