"""CPU PhoBERT CLS features with shared Vietnamese preprocessing."""

from collections.abc import Sequence
from dataclasses import replace
from pathlib import Path

import numpy as np
import torch
from transformers import AutoModel, AutoTokenizer
from underthesea import word_tokenize

from app.infrastructure.ai.classifier.config import MODEL_CACHE_DIR, ClassifierConfig


def preprocess_text(text: str) -> str:
    """Lowercase, normalize whitespace, and segment Vietnamese compound words."""
    if not isinstance(text, str):
        raise TypeError("Transaction text must be a string")
    normalized = " ".join(text.lower().split())
    if not normalized:
        raise ValueError("Transaction text must not be empty")
    segmented = word_tokenize(normalized, format="text")
    if not isinstance(segmented, str) or not segmented.strip():
        raise ValueError("Vietnamese segmentation returned no text")
    return segmented


class PhoBERTEmbedder:
    """Reuse an evaluation-mode CPU encoder and cached Hugging Face downloads."""

    def __init__(
        self,
        model_name: str = "vinai/phobert-base",
        *,
        cache_dir: Path = MODEL_CACHE_DIR,
        local_files_only: bool = False,
        config: ClassifierConfig | None = None,
    ) -> None:
        """Load once, preferring local files; offline mode never downloads."""
        self.config = config or ClassifierConfig(model_name=model_name)
        self.model_name = self.config.model_name
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        try:
            try:
                self._load(local_files_only=True)
            except OSError:
                if local_files_only:
                    raise
                self._load(local_files_only=False)
        except (OSError, ValueError, RuntimeError) as exc:
            raise RuntimeError(
                f"Cannot load PhoBERT from {self.cache_dir}. "
                "Populate the cache during training before offline inference."
            ) from exc
        self.model.to("cpu")
        self.model.eval()
        if self.model.config.hidden_size != self.config.embedding_dim:
            raise ValueError("PhoBERT hidden size must be 768")
        revision = getattr(self.model.config, "_commit_hash", None)
        if isinstance(revision, str) and revision:
            self.config = replace(self.config, revision=revision)

    def _load(self, *, local_files_only: bool) -> None:
        """Load tokenizer and encoder from the same model revision."""
        self.tokenizer = AutoTokenizer.from_pretrained(
            self.model_name,
            cache_dir=str(self.cache_dir),
            revision=self.config.revision,
            local_files_only=local_files_only,
        )
        self.model = AutoModel.from_pretrained(
            self.model_name,
            cache_dir=str(self.cache_dir),
            revision=self.config.revision,
            local_files_only=local_files_only,
        )

    def embed(self, text: str) -> np.ndarray:
        """Return a finite float32 CLS vector of shape (768,) on CPU."""
        return self.embed_batch([text], batch_size=1)[0]

    def embed_batch(self, texts: Sequence[str], *, batch_size: int = 16) -> np.ndarray:
        """Extract bounded batches using dynamic padding and no gradients."""
        if isinstance(texts, str):
            raise TypeError("embed_batch expects a sequence of strings")
        if batch_size < 1:
            raise ValueError("batch_size must be positive")
        features = np.empty((len(texts), self.config.embedding_dim), dtype=np.float32)
        for start in range(0, len(texts), batch_size):
            segmented = [preprocess_text(t) for t in texts[start : start + batch_size]]
            try:
                inputs = self.tokenizer(
                    segmented,
                    return_tensors="pt",
                    padding=True,
                    truncation=True,
                    max_length=self.config.max_length,
                    return_token_type_ids=False,
                )
                with torch.no_grad():
                    output = self.model(**inputs)
                    vectors = output.last_hidden_state[:, 0, :].cpu().numpy()
            except (ValueError, RuntimeError) as exc:
                raise RuntimeError("PhoBERT CPU embedding extraction failed") from exc
            if vectors.shape != (len(segmented), self.config.embedding_dim):
                raise RuntimeError("Unexpected PhoBERT CLS feature shape")
            if not np.isfinite(vectors).all():
                raise RuntimeError("PhoBERT returned non-finite embeddings")
            features[start : start + len(segmented)] = vectors
        return features
