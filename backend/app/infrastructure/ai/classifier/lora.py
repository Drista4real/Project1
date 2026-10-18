"""Load standalone LoRA artifacts without model downloads at import."""

import json
from pathlib import Path

import torch
from transformers import AutoModelForSequenceClassification, AutoTokenizer

from app.domain.interfaces.classifier_interface import (
    ClassificationResult,
    ITransactionClassifier,
)
from app.infrastructure.ai.classifier.config import CATEGORIES, CONFIDENCE_THRESHOLD
from app.infrastructure.ai.classifier.phobert_embedder import preprocess_text


def select_device(name: str) -> torch.device:
    """Require an explicit CPU opt-in rather than silently training without a GPU."""
    if name not in ("cpu", "cuda"):
        raise ValueError("Device must be cpu or cuda")
    if name == "cuda" and not torch.cuda.is_available():
        raise ValueError(
            "CUDA unavailable: select a T4 GPU runtime or use --device cpu"
        )
    return torch.device(name)


class LoRAClassifier(ITransactionClassifier):
    """Reload the base, classifier head and adapter with shared preprocessing."""

    def __init__(
        self,
        artifact_dir: Path,
        *,
        device: str = "cpu",
        cache_dir: Path | None = None,
        local_files_only: bool = False,
    ) -> None:
        from peft import PeftModel

        self.device = select_device(device)
        self.metadata = json.loads(
            (artifact_dir / "lora_config.json").read_text(encoding="utf-8")
        )
        labels = self.metadata["labels"]
        if (
            self.metadata["schema_version"] != 1
            or labels != sorted(CATEGORIES)
            or self.metadata["preprocessing"] != "lower_whitespace_underthesea_text_v1"
            or not 2 <= self.metadata["max_length"] <= 256
            or self.metadata["confidence_threshold"] != CONFIDENCE_THRESHOLD
        ):
            raise ValueError("Unsupported LoRA artifact metadata")
        self.labels = labels
        self.tokenizer = AutoTokenizer.from_pretrained(
            artifact_dir, local_files_only=True, use_fast=False
        )
        base = AutoModelForSequenceClassification.from_pretrained(
            self.metadata["base_model"],
            revision=self.metadata["base_revision"],
            num_labels=len(labels),
            id2label=dict(enumerate(labels)),
            label2id={label: i for i, label in enumerate(labels)},
            cache_dir=str(cache_dir) if cache_dir else None,
            local_files_only=local_files_only,
        )
        self.model = PeftModel.from_pretrained(base, artifact_dir, is_trainable=False)
        self.model.to(self.device).eval()

    def predict(self, text: str) -> dict[str, str | float]:
        """Return a suggestion and confidence without making cloud calls."""
        inputs = self.tokenizer(
            preprocess_text(text),
            truncation=True,
            max_length=self.metadata["max_length"],
            return_tensors="pt",
            return_token_type_ids=False,
        ).to(self.device)
        with torch.inference_mode():
            probabilities = self.model(**inputs).logits.float().softmax(dim=-1)[0]
        if not torch.isfinite(probabilities).all():
            raise RuntimeError("Non-finite classifier probabilities")
        confidence, index = probabilities.max(dim=-1)
        score = float(confidence.item())
        return {
            "category": self.labels[int(index.item())],
            "confidence": score,
            "source": "LOCAL" if score >= CONFIDENCE_THRESHOLD else "CLOUD_FALLBACK",
        }

    def classify(self, text: str) -> ClassificationResult:
        """Adapt the saved LoRA classifier to the transaction parsing contract."""
        result = self.predict(text)
        return ClassificationResult(
            label=str(result["category"]), confidence=float(result["confidence"])
        )
