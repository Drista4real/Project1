"""Local LightGBM inference and confidence-based cloud routing."""

import pickle
from dataclasses import replace
from pathlib import Path
from typing import TypeVar

import numpy as np
from lightgbm import LGBMClassifier
from lightgbm.basic import LightGBMError
from sklearn.preprocessing import LabelEncoder
from sklearn.utils.validation import check_is_fitted

from app.domain.interfaces.classifier_interface import (
    ClassificationResult,
    ITransactionClassifier,
)
from app.infrastructure.ai.classifier.config import (
    CATEGORIES,
    CHECKPOINT_DIR,
    CONFIDENCE_THRESHOLD,
    ClassifierConfig,
)
from app.infrastructure.ai.classifier.phobert_embedder import PhoBERTEmbedder

Artifact = TypeVar("Artifact")


def _load_artifact(  # noqa: UP047 -- retain Python 3.10+ syntax per RULES.md
    path: Path, expected_type: type[Artifact]
) -> Artifact:
    """Load a trusted local training artifact and validate its type and fit."""
    try:
        with path.open("rb") as stream:
            artifact = pickle.load(stream)
    except FileNotFoundError as exc:
        raise FileNotFoundError(
            f"Missing classifier artifact: {path}. Run training."
        ) from exc
    except (
        OSError,
        pickle.UnpicklingError,
        EOFError,
        ImportError,
        AttributeError,
    ) as exc:
        raise RuntimeError(f"Cannot load classifier artifact: {path}") from exc
    if not isinstance(artifact, expected_type):
        raise ValueError(
            f"Invalid artifact type in {path}: expected {expected_type.__name__}"
        )
    check_is_fitted(artifact)
    return artifact


class LightGBMTransactionClassifier(ITransactionClassifier):
    """Implement the domain port and return a hint for cloud orchestration."""

    def __init__(
        self,
        model_path: Path = CHECKPOINT_DIR / "lgbm_classifier.pkl",
        embedder: PhoBERTEmbedder | None = None,
        *,
        label_encoder_path: Path | None = None,
        config_path: Path | None = None,
    ) -> None:
        """Load artifacts once and use cached PhoBERT for offline inference."""
        self.model_path = Path(model_path)
        encoder_path = label_encoder_path or self.model_path.with_name(
            "label_encoder.pkl"
        )
        metadata_path = config_path or self.model_path.with_name(
            "classifier_config.json"
        )
        self.config = (
            ClassifierConfig.load(metadata_path)
            if config_path is not None or metadata_path.exists()
            else ClassifierConfig()
        )
        self.model = _load_artifact(self.model_path, LGBMClassifier)
        self.label_encoder = _load_artifact(Path(encoder_path), LabelEncoder)
        if not np.array_equal(self.label_encoder.classes_, np.sort(CATEGORIES)):
            raise ValueError(
                "Label encoder must contain the six transaction categories"
            )
        if self.model.n_features_in_ != self.config.embedding_dim:
            raise ValueError("LightGBM must accept 768-dimensional PhoBERT features")
        if not np.array_equal(self.model.classes_, np.arange(len(CATEGORIES))):
            raise ValueError("LightGBM classes do not match the encoded labels")
        self.embedder = embedder or PhoBERTEmbedder(
            config=self.config, local_files_only=True
        )
        embedding_config = self.embedder.config
        if config_path is None and not metadata_path.exists():
            # Legacy two-artifact bundles use default features and resolve main locally.
            embedding_config = replace(embedding_config, revision=self.config.revision)
        if embedding_config != self.config:
            raise ValueError("Embedder configuration differs from training")
        self.model.set_params(n_jobs=1)

    def predict(self, text: str) -> tuple[str, float, str]:
        """Return (category, P, LOCAL if P >= 0.8 else CLOUD_FALLBACK)."""
        vector = self.embedder.embed(text)
        if (
            vector.shape != (self.config.embedding_dim,)
            or not np.isfinite(vector).all()
        ):
            raise ValueError("Expected a finite 768-dimensional embedding")
        try:
            probabilities = np.asarray(self.model.predict_proba(vector.reshape(1, -1)))
        except (ValueError, RuntimeError, LightGBMError) as exc:
            raise RuntimeError("LightGBM classification failed") from exc
        if (
            probabilities.shape != (1, len(CATEGORIES))
            or not np.isfinite(probabilities).all()
            or (probabilities < 0).any()
            or (probabilities > 1).any()
            or not np.isclose(probabilities.sum(), 1.0)
        ):
            raise RuntimeError("LightGBM returned invalid category probabilities")
        index = int(np.argmax(probabilities[0]))
        confidence = float(probabilities[0, index])
        encoded_label = int(self.model.classes_[index])
        category = str(self.label_encoder.inverse_transform([encoded_label])[0])
        source = "LOCAL" if confidence >= CONFIDENCE_THRESHOLD else "CLOUD_FALLBACK"
        return category, confidence, source

    def classify(self, text: str) -> ClassificationResult:
        """Adapt prediction to the existing application/domain contract."""
        category, confidence, _source = self.predict(text)
        return ClassificationResult(label=category, confidence=confidence)
