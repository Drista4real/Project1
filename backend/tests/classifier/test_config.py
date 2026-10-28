"""Unit tests for classifier configuration."""

import json
from pathlib import Path

import pytest

from app.infrastructure.ai.classifier.config import (
    CATEGORIES,
    CHECKPOINT_DIR,
    CONFIDENCE_THRESHOLD,
    ClassifierConfig,
)


class TestClassifierConfig:
    """Tests for ClassifierConfig dataclass and validation."""

    def test_default_values(self) -> None:
        """Test default configuration values."""
        config = ClassifierConfig()
        assert config.schema_version == 1
        assert config.model_name == "vinai/phobert-base"
        assert config.revision == "main"
        assert config.max_length == 256
        assert config.embedding_dim == 768
        assert config.pooling == "cls"
        assert config.preprocessing == "lower_whitespace_underthesea_text_v1"
        assert config.confidence_threshold == CONFIDENCE_THRESHOLD

    def test_custom_values(self) -> None:
        """Test custom configuration values."""
        config = ClassifierConfig(
            schema_version=1,
            model_name="vinai/phobert-base",
            revision="abc123",
            max_length=128,
            embedding_dim=768,
            pooling="cls",
            preprocessing="lower_whitespace_underthesea_text_v1",
            confidence_threshold=0.8,
        )
        assert config.revision == "abc123"
        assert config.max_length == 128

    def test_post_init_valid_schema_version(self) -> None:
        """Test that invalid schema_version raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(schema_version=2)

    def test_post_init_invalid_model_name(self) -> None:
        """Test that invalid model_name raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(model_name="invalid/model")

    def test_post_init_empty_revision(self) -> None:
        """Test that empty revision raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(revision="")

    def test_post_init_invalid_max_length_type(self) -> None:
        """Test that non-int max_length raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(max_length=256.0)  # type: ignore

    def test_post_init_max_length_too_small(self) -> None:
        """Test that max_length < 2 raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(max_length=1)

    def test_post_init_max_length_too_large(self) -> None:
        """Test that max_length > 256 raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(max_length=257)

    def test_post_init_invalid_embedding_dim(self) -> None:
        """Test that embedding_dim != 768 raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(embedding_dim=512)

    def test_post_init_invalid_pooling(self) -> None:
        """Test that pooling != 'cls' raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(pooling="mean")

    def test_post_init_invalid_preprocessing(self) -> None:
        """Test that invalid preprocessing raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(preprocessing="invalid")

    def test_post_init_invalid_confidence_threshold(self) -> None:
        """Test that confidence_threshold != CONFIDENCE_THRESHOLD raises ValueError."""
        with pytest.raises(
            ValueError, match="Unsupported classifier feature configuration"
        ):
            ClassifierConfig(confidence_threshold=0.7)

    def test_load_valid_config(self, tmp_path: Path) -> None:
        """Test loading valid configuration from JSON."""
        config_data = {
            "schema_version": 1,
            "model_name": "vinai/phobert-base",
            "revision": "test_rev",
            "max_length": 256,
            "embedding_dim": 768,
            "pooling": "cls",
            "preprocessing": "lower_whitespace_underthesea_text_v1",
            "confidence_threshold": 0.8,
        }
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(config_data), encoding="utf-8")

        config = ClassifierConfig.load(config_path)
        assert config.revision == "test_rev"

    def test_load_invalid_json(self, tmp_path: Path) -> None:
        """Test loading invalid JSON raises ValueError."""
        config_path = tmp_path / "config.json"
        config_path.write_text("invalid json", encoding="utf-8")

        with pytest.raises(ValueError, match="Cannot load classifier configuration"):
            ClassifierConfig.load(config_path)

    def test_load_not_object(self, tmp_path: Path) -> None:
        """Test loading non-object JSON raises ValueError."""
        config_path = tmp_path / "config.json"
        config_path.write_text(json.dumps(["not", "an", "object"]), encoding="utf-8")

        with pytest.raises(ValueError, match="Cannot load classifier configuration"):
            ClassifierConfig.load(config_path)

    def test_load_missing_file(self, tmp_path: Path) -> None:
        """Test loading missing file raises ValueError."""
        with pytest.raises(ValueError, match="Cannot load classifier configuration"):
            ClassifierConfig.load(tmp_path / "missing.json")

    def test_save_config(self, tmp_path: Path) -> None:
        """Test saving configuration to JSON."""
        config = ClassifierConfig(revision="save_test")
        config_path = tmp_path / "config.json"
        config.save(config_path)

        loaded = json.loads(config_path.read_text(encoding="utf-8"))
        assert loaded["revision"] == "save_test"
        assert loaded["schema_version"] == 1

    def test_constants(self) -> None:
        """Test module-level constants."""
        assert CATEGORIES == (
            "Ăn uống",
            "Đi lại",
            "Mua sắm",
            "Hóa đơn/Nhà ở",
            "Y tế",
            "Khác",
        )
        assert CONFIDENCE_THRESHOLD == 0.8
        assert CHECKPOINT_DIR.name == "checkpoints"
