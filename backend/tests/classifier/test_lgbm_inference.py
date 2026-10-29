"""Unit tests for LightGBM transaction classifier."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pytest
from lightgbm import LGBMClassifier
from sklearn.preprocessing import LabelEncoder

from app.domain.interfaces.classifier_interface import ClassificationResult
from app.infrastructure.ai.classifier.config import (
    CATEGORIES,
    ClassifierConfig,
)
from app.infrastructure.ai.classifier.lgbm_inference import (
    LightGBMTransactionClassifier,
    _load_artifact,
)
from app.infrastructure.ai.classifier.phobert_embedder import PhoBERTEmbedder


class TestLoadArtifact:
    """Tests for _load_artifact helper function."""

    def test_load_valid_artifact(self, tmp_path: Path) -> None:
        """Test loading a valid pickle artifact."""
        artifact = LabelEncoder()
        artifact.fit(np.sort(np.array(CATEGORIES)))
        artifact_path = tmp_path / "artifact.pkl"
        import pickle

        artifact_path.write_bytes(pickle.dumps(artifact))

        result = _load_artifact(artifact_path, LabelEncoder)
        assert isinstance(result, LabelEncoder)
        np.testing.assert_array_equal(result.classes_, artifact.classes_)

    def test_load_missing_file(self, tmp_path: Path) -> None:
        """Test loading missing file raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError, match="Missing classifier artifact"):
            _load_artifact(tmp_path / "missing.pkl", LabelEncoder)

    def test_load_corrupted_pickle(self, tmp_path: Path) -> None:
        """Test loading corrupted pickle raises RuntimeError."""
        artifact_path = tmp_path / "corrupted.pkl"
        artifact_path.write_bytes(b"not a pickle")

        with pytest.raises(RuntimeError, match="Cannot load classifier artifact"):
            _load_artifact(artifact_path, LabelEncoder)

    def test_load_wrong_type(self, tmp_path: Path) -> None:
        """Test loading artifact of wrong type raises ValueError."""
        artifact = "not a label encoder"
        artifact_path = tmp_path / "artifact.pkl"
        import pickle

        artifact_path.write_bytes(pickle.dumps(artifact))

        with pytest.raises(ValueError, match="Invalid artifact type"):
            _load_artifact(artifact_path, LabelEncoder)

    def test_load_unfitted_encoder(self, tmp_path: Path) -> None:
        """Test loading unfitted LabelEncoder raises error."""
        artifact = LabelEncoder()
        artifact_path = tmp_path / "artifact.pkl"
        import pickle

        artifact_path.write_bytes(pickle.dumps(artifact))

        from sklearn.utils.validation import NotFittedError

        with pytest.raises(NotFittedError):
            _load_artifact(artifact_path, LabelEncoder)


class TestLightGBMTransactionClassifier:
    """Tests for LightGBMTransactionClassifier."""

    @pytest.fixture
    def artifact_config(self) -> dict:
        """Standard artifact config matching training."""
        return {
            "schema_version": 1,
            "model_name": "vinai/phobert-base",
            "revision": "test",
            "max_length": 256,
            "embedding_dim": 768,
            "pooling": "cls",
            "preprocessing": "lower_whitespace_underthesea_text_v1",
            "confidence_threshold": 0.8,
        }

    @pytest.fixture
    def fitted_model(self, artifact_config) -> LGBMClassifier:
        """Create a fitted LightGBM model with classes 0-5 that can be pickled."""
        model = LGBMClassifier(n_estimators=1, random_state=42, verbose=-1)
        # Ensure all 6 classes are present in training data
        X_train = np.random.default_rng(42).random((12, 768)).astype(np.float32)
        y_train = np.array([0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5])  # All 6 classes
        model.fit(X_train, y_train)
        return model

    @pytest.fixture
    def fitted_label_encoder(self) -> LabelEncoder:
        """Create a fitted LabelEncoder with sorted CATEGORIES."""
        encoder = LabelEncoder()
        encoder.fit(np.sort(np.array(CATEGORIES)))
        return encoder

    @pytest.fixture
    def mock_embedder(self, artifact_config):
        """Create a mock PhoBERT embedder with matching config."""
        embedder = MagicMock(spec=PhoBERTEmbedder)
        embedder.config = ClassifierConfig(**artifact_config)
        embedder.embed.return_value = (
            np.random.default_rng(42).random((768,)).astype(np.float32)
        )
        return embedder

    def _create_artifact_files(
        self, tmp_path: Path, model, label_encoder, config_dict=None
    ):
        """Helper to create artifact files."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(model))
        encoder_path.write_bytes(pickle.dumps(label_encoder))

        if config_dict is None:
            config_dict = {
                "schema_version": 1,
                "model_name": "vinai/phobert-base",
                "revision": "test",
                "max_length": 256,
                "embedding_dim": 768,
                "pooling": "cls",
                "preprocessing": "lower_whitespace_underthesea_text_v1",
                "confidence_threshold": 0.8,
            }
        config_path.write_text(json.dumps(config_dict))

        return model_path, encoder_path, config_path

    def test_init_loads_artifacts(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test initialization loads all artifacts."""
        model_path, encoder_path, config_path = self._create_artifact_files(
            tmp_path, fitted_model, fitted_label_encoder, artifact_config
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )

            assert classifier.model is not None
            assert classifier.label_encoder is not None
            assert classifier.embedder is mock_embedder
            np.testing.assert_array_equal(
                classifier.label_encoder.classes_, fitted_label_encoder.classes_
            )

    def test_init_validates_label_encoder_categories(
        self, tmp_path: Path, fitted_model, mock_embedder, artifact_config
    ) -> None:
        """Test that label encoder must have correct categories."""
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"

        model_path.write_bytes(pickle.dumps(fitted_model))

        # Wrong categories
        bad_encoder = LabelEncoder()
        bad_encoder.fit(np.array(["wrong", "categories"]))
        encoder_path.write_bytes(pickle.dumps(bad_encoder))

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            with pytest.raises(
                ValueError,
                match="Label encoder must contain the six transaction categories",
            ):
                LightGBMTransactionClassifier(
                    model_path=model_path,
                    label_encoder_path=encoder_path,
                    embedder=mock_embedder,
                )

    def test_init_validates_model_features(
        self, tmp_path: Path, fitted_label_encoder, mock_embedder, artifact_config
    ) -> None:
        """Test that model must accept 768 features."""
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"

        # Wrong feature count - create model with 512 features
        bad_model = LGBMClassifier(n_estimators=1, random_state=42, verbose=-1)
        X_train = np.random.default_rng(42).random((12, 512)).astype(np.float32)
        y_train = np.array([0, 1, 2, 3, 4, 5, 0, 1, 2, 3, 4, 5])
        bad_model.fit(X_train, y_train)

        model_path.write_bytes(pickle.dumps(bad_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            with pytest.raises(
                ValueError, match="LightGBM must accept 768-dimensional"
            ):
                LightGBMTransactionClassifier(
                    model_path=model_path,
                    label_encoder_path=encoder_path,
                    embedder=mock_embedder,
                )

    def test_init_validates_model_classes(
        self, tmp_path: Path, fitted_label_encoder, mock_embedder, artifact_config
    ) -> None:
        """Test that model classes match encoded labels."""
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"

        # Model with wrong classes (not 0-5)
        bad_model = LGBMClassifier(n_estimators=1, random_state=42, verbose=-1)
        X_train = np.random.default_rng(42).random((12, 768)).astype(np.float32)
        y_train = np.array(
            [10, 11, 12, 13, 14, 15, 10, 11, 12, 13, 14, 15]
        )  # Classes 10-15
        bad_model.fit(X_train, y_train)

        model_path.write_bytes(pickle.dumps(bad_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            with pytest.raises(ValueError, match="LightGBM classes do not match"):
                LightGBMTransactionClassifier(
                    model_path=model_path,
                    label_encoder_path=encoder_path,
                    embedder=mock_embedder,
                )

    def test_init_validates_embedder_config(
        self, tmp_path: Path, fitted_model, fitted_label_encoder, artifact_config
    ) -> None:
        """Test that embedder config matches classifier config."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        # Different embedder config
        bad_embedder = MagicMock(spec=PhoBERTEmbedder)
        bad_embedder.config = ClassifierConfig(max_length=128)  # Different!

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=bad_embedder,
        ):
            with pytest.raises(
                ValueError, match="Embedder configuration differs from training"
            ):
                LightGBMTransactionClassifier(
                    model_path=model_path,
                    label_encoder_path=encoder_path,
                    config_path=config_path,
                    embedder=bad_embedder,
                )

    def test_predict_high_confidence_local(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test prediction with high confidence returns LOCAL."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        mock_embedder.embed.return_value = (
            np.random.default_rng(42).random((768,)).astype(np.float32)
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            category, confidence, source = classifier.predict("test text")

            assert category in CATEGORIES
            assert isinstance(confidence, float)
            assert source in ("LOCAL", "CLOUD_FALLBACK")

    def test_predict_low_confidence_cloud_fallback(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test prediction with low confidence returns CLOUD_FALLBACK."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        mock_embedder.embed.return_value = (
            np.random.default_rng(42).random((768,)).astype(np.float32)
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            category, confidence, source = classifier.predict("test text")

            assert category in CATEGORIES
            assert isinstance(confidence, float)
            assert source in ("LOCAL", "CLOUD_FALLBACK")

    def test_predict_invalid_embedding_shape(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test that invalid embedding shape raises ValueError."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        # Wrong embedding dimension
        mock_embedder.embed.return_value = (
            np.random.default_rng(42).random((512,)).astype(np.float32)
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            with pytest.raises(
                ValueError, match="Expected a finite 768-dimensional embedding"
            ):
                classifier.predict("test text")

    def test_predict_non_finite_embedding(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test that non-finite embedding raises ValueError."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        # Embedding with NaN
        mock_embedder.embed.return_value = np.array(
            [1.0, np.nan] + [0.0] * 766, dtype=np.float32
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            with pytest.raises(
                ValueError, match="Expected a finite 768-dimensional embedding"
            ):
                classifier.predict("test text")

    def test_predict_model_failure(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test that model prediction failure raises RuntimeError."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        mock_embedder.embed.return_value = (
            np.random.default_rng(42).random((768,)).astype(np.float32)
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            # Patch the classifier's model after creation
            with patch.object(
                classifier.model, "predict_proba", side_effect=ValueError("Model error")
            ):
                with pytest.raises(
                    RuntimeError, match="LightGBM classification failed"
                ):
                    classifier.predict("test text")

    def test_predict_invalid_probabilities_shape(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test that invalid probability shape raises RuntimeError."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        mock_embedder.embed.return_value = (
            np.random.default_rng(42).random((768,)).astype(np.float32)
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            # Mock predict_proba to return wrong shape
            with patch.object(
                classifier.model,
                "predict_proba",
                return_value=np.array([[0.1, 0.2, 0.3]]),
            ):
                with pytest.raises(
                    RuntimeError,
                    match="LightGBM returned invalid category probabilities",
                ):
                    classifier.predict("test text")

    def test_predict_invalid_probabilities_values(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test that invalid probability values raise RuntimeError."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        mock_embedder.embed.return_value = (
            np.random.default_rng(42).random((768,)).astype(np.float32)
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            # Probabilities don't sum to 1
            with patch.object(
                classifier.model,
                "predict_proba",
                return_value=np.array([[0.5, 0.5, 0.5, 0.5, 0.5, 0.5]]),
            ):
                with pytest.raises(
                    RuntimeError,
                    match="LightGBM returned invalid category probabilities",
                ):
                    classifier.predict("test text")

    def test_classify_adapts_to_domain_contract(
        self,
        tmp_path: Path,
        fitted_model,
        fitted_label_encoder,
        mock_embedder,
        artifact_config,
    ) -> None:
        """Test classify method returns ClassificationResult."""
        import json
        import pickle

        model_path = tmp_path / "model.pkl"
        encoder_path = tmp_path / "label_encoder.pkl"
        config_path = tmp_path / "config.json"

        model_path.write_bytes(pickle.dumps(fitted_model))
        encoder_path.write_bytes(pickle.dumps(fitted_label_encoder))
        config_path.write_text(json.dumps(artifact_config))

        mock_embedder.embed.return_value = (
            np.random.default_rng(42).random((768,)).astype(np.float32)
        )

        with patch(
            "app.infrastructure.ai.classifier.lgbm_inference.PhoBERTEmbedder",
            return_value=mock_embedder,
        ):
            classifier = LightGBMTransactionClassifier(
                model_path=model_path,
                label_encoder_path=encoder_path,
                config_path=config_path,
                embedder=mock_embedder,
            )
            result = classifier.classify("test text")

            assert isinstance(result, ClassificationResult)
            assert result.label in CATEGORIES
            assert 0 <= result.confidence <= 1
