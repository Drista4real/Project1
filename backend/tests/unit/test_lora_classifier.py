"""Tests for LoRA classifier."""

import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, Mock, patch

import pytest

from app.domain.interfaces.classifier_interface import ClassificationResult
from app.infrastructure.ai.classifier.config import CATEGORIES, CONFIDENCE_THRESHOLD
from app.infrastructure.ai.classifier.lora import (
    LoRAClassifier,
    select_device,
)


class TestSelectDevice:
    """Tests for select_device function."""

    def test_select_cpu(self):
        """Test selecting CPU device."""
        device = select_device("cpu")
        assert str(device) == "cpu"

    def test_select_cuda_when_available(self):
        """Test selecting CUDA device when available."""
        with patch("torch.cuda.is_available", return_value=True):
            device = select_device("cuda")
            assert str(device) == "cuda"

    def test_select_cuda_when_unavailable_raises(self):
        """Test selecting CUDA when unavailable raises ValueError."""
        with patch("torch.cuda.is_available", return_value=False):
            with pytest.raises(ValueError, match="CUDA unavailable"):
                select_device("cuda")

    def test_select_invalid_device_raises(self):
        """Test selecting invalid device raises ValueError."""
        with pytest.raises(ValueError, match="Device must be cpu or cuda"):
            select_device("mps")
        with pytest.raises(ValueError, match="Device must be cpu or cuda"):
            select_device("gpu")


class TestLoRAClassifier:
    """Tests for LoRAClassifier."""

    @pytest.fixture(autouse=True)
    def setup_artifacts(self, monkeypatch):
        self.peft_mock = MagicMock()
        monkeypatch.setitem(sys.modules, "peft", self.peft_mock)
        self.artifact_dir = Path("/fake/artifact/dir")
        self.mock_metadata = {
            "schema_version": 1,
            "labels": sorted(CATEGORIES),
            "preprocessing": "lower_whitespace_underthesea_text_v1",
            "max_length": 256,
            "confidence_threshold": CONFIDENCE_THRESHOLD,
            "base_model": "vinai/phobert-base",
            "base_revision": "main",
        }

    def create_mock_artifact_dir(self, tmp_path, metadata=None):
        """Create a mock artifact directory with config file."""
        if metadata is None:
            metadata = self.mock_metadata
        artifact_dir = tmp_path / "lora_artifact"
        artifact_dir.mkdir()
        config_file = artifact_dir / "lora_config.json"
        config_file.write_text(json.dumps(metadata), encoding="utf-8")
        return artifact_dir

    @patch("app.infrastructure.ai.classifier.lora.AutoTokenizer")
    @patch("app.infrastructure.ai.classifier.lora.AutoModelForSequenceClassification")
    @patch("app.infrastructure.ai.classifier.lora.torch")
    def test_init_loads_all_components(
        self, mock_torch, mock_auto_model, mock_tokenizer, tmp_path
    ):
        """Test initialization loads tokenizer, base model, and LoRA adapter."""
        artifact_dir = self.create_mock_artifact_dir(tmp_path)

        # Setup mocks
        mock_tokenizer.from_pretrained.return_value = MagicMock()
        mock_base_model = MagicMock()
        mock_auto_model.from_pretrained.return_value = mock_base_model
        mock_peft_model = MagicMock()
        self.peft_mock.PeftModel.from_pretrained.return_value = mock_peft_model

        # Chain mock for .to().eval()
        mock_peft_model.to.return_value = mock_peft_model

        mock_torch.device.return_value = "cpu"
        mock_torch.cuda.is_available.return_value = False
        mock_torch.inference_mode.return_value.__enter__ = Mock(return_value=None)
        mock_torch.inference_mode.return_value.__exit__ = Mock(return_value=None)

        LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

        # Verify tokenizer loaded
        mock_tokenizer.from_pretrained.assert_called_once_with(
            artifact_dir, local_files_only=True, use_fast=False
        )
        # Verify base model loaded
        mock_auto_model.from_pretrained.assert_called_once()
        # Verify LoRA adapter applied
        self.peft_mock.PeftModel.from_pretrained.assert_called_once_with(
            mock_base_model, artifact_dir, is_trainable=False
        )
        # Verify model moved to device and set to eval (chained call)
        mock_peft_model.to.assert_called_once_with("cpu")
        mock_peft_model.eval.assert_called_once()

    def test_init_invalid_schema_version_raises(self, tmp_path):
        """Test initialization raises ValueError for invalid schema version."""
        metadata = {**self.mock_metadata, "schema_version": 2}
        artifact_dir = self.create_mock_artifact_dir(tmp_path, metadata)

        with pytest.raises(ValueError, match="Unsupported LoRA artifact metadata"):
            LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

    def test_init_invalid_labels_raises(self, tmp_path):
        """Test initialization raises ValueError for invalid labels."""
        metadata = {**self.mock_metadata, "labels": ["wrong", "labels"]}
        artifact_dir = self.create_mock_artifact_dir(tmp_path, metadata)

        with pytest.raises(ValueError, match="Unsupported LoRA artifact metadata"):
            LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

    def test_init_invalid_preprocessing_raises(self, tmp_path):
        """Test initialization raises ValueError for invalid preprocessing."""
        metadata = {**self.mock_metadata, "preprocessing": "invalid"}
        artifact_dir = self.create_mock_artifact_dir(tmp_path, metadata)

        with pytest.raises(ValueError, match="Unsupported LoRA artifact metadata"):
            LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

    def test_init_invalid_max_length_raises(self, tmp_path):
        """Test initialization raises ValueError for invalid max_length."""
        metadata = {**self.mock_metadata, "max_length": 1000}
        artifact_dir = self.create_mock_artifact_dir(tmp_path, metadata)

        with pytest.raises(ValueError, match="Unsupported LoRA artifact metadata"):
            LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

    def test_init_invalid_confidence_threshold_raises(self, tmp_path):
        """Test initialization raises ValueError for invalid confidence threshold."""
        metadata = {**self.mock_metadata, "confidence_threshold": 0.5}
        artifact_dir = self.create_mock_artifact_dir(tmp_path, metadata)

        with pytest.raises(ValueError, match="Unsupported LoRA artifact metadata"):
            LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

    def _setup_predict_mocks(
        self,
        mock_torch,
        mock_auto_model,
        mock_tokenizer,
        tmp_path,
        confidence=0.9,
        index=1,
    ):
        """Setup common mocks for predict tests."""
        artifact_dir = self.create_mock_artifact_dir(tmp_path)

        # Setup tokenizer mock
        mock_tokenizer_instance = MagicMock()
        mock_tokenizer.from_pretrained.return_value = mock_tokenizer_instance

        # Tokenizer returns a dict-like object with .to() method
        mock_inputs = MagicMock()
        mock_inputs.to.return_value = mock_inputs
        mock_tokenizer_instance.return_value = mock_inputs

        # Setup model chain: model(**inputs) -> .logits -> .float() -> .softmax(dim=-1)
        # -> [0] -> .max(dim=-1)
        mock_base_model = MagicMock()
        mock_auto_model.from_pretrained.return_value = mock_base_model
        mock_peft_model = MagicMock()
        self.peft_mock.PeftModel.from_pretrained.return_value = mock_peft_model
        mock_peft_model.to.return_value = mock_peft_model
        mock_peft_model.eval.return_value = None

        # Build the chain: model(**inputs).logits.float().softmax(dim=-1)[0].max(dim=-1)
        mock_model_output = MagicMock()
        mock_logits = MagicMock()
        mock_float = MagicMock()
        mock_softmax = MagicMock()
        mock_probs = MagicMock()
        mock_confidence = MagicMock()
        mock_index = MagicMock()

        mock_confidence.item.return_value = confidence
        mock_index.item.return_value = index
        mock_probs.max.return_value = (mock_confidence, mock_index)
        mock_softmax.__getitem__.return_value = mock_probs
        mock_float.softmax.return_value = mock_softmax
        mock_logits.float.return_value = mock_float
        mock_model_output.logits = mock_logits
        mock_peft_model.return_value = mock_model_output

        mock_torch.device.return_value = "cpu"
        mock_torch.cuda.is_available.return_value = False
        mock_torch.isfinite.return_value.all.return_value = True
        mock_torch.inference_mode.return_value.__enter__ = Mock(return_value=None)
        mock_torch.inference_mode.return_value.__exit__ = Mock(return_value=None)

        classifier = LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

        return classifier, mock_peft_model

    @patch("app.infrastructure.ai.classifier.lora.AutoTokenizer")
    @patch("app.infrastructure.ai.classifier.lora.AutoModelForSequenceClassification")
    @patch("app.infrastructure.ai.classifier.lora.torch")
    def test_predict_returns_dict_with_category_confidence_source(
        self, mock_torch, mock_auto_model, mock_tokenizer, tmp_path
    ):
        """Test predict returns dict with category, confidence, and source."""
        classifier, mock_peft_model = self._setup_predict_mocks(
            mock_torch,
            mock_auto_model,
            mock_tokenizer,
            tmp_path,
            confidence=0.9,
            index=1,
        )

        with patch.object(classifier, "model", mock_peft_model):
            with patch(
                "app.infrastructure.ai.classifier.lora.preprocess_text",
                return_value="processed text",
            ):
                result = classifier.predict("Test text")

        assert isinstance(result, dict)
        assert "category" in result
        assert "confidence" in result
        assert "source" in result
        assert result["category"] == sorted(CATEGORIES)[1]  # Index 1
        assert result["confidence"] == 0.9
        assert result["source"] == "LOCAL"

    @patch("app.infrastructure.ai.classifier.lora.AutoTokenizer")
    @patch("app.infrastructure.ai.classifier.lora.AutoModelForSequenceClassification")
    @patch("app.infrastructure.ai.classifier.lora.torch")
    def test_predict_low_confidence_returns_cloud_fallback(
        self, mock_torch, mock_auto_model, mock_tokenizer, tmp_path
    ):
        """Test predict returns CLOUD_FALLBACK for low confidence."""
        classifier, mock_peft_model = self._setup_predict_mocks(
            mock_torch,
            mock_auto_model,
            mock_tokenizer,
            tmp_path,
            confidence=0.5,
            index=1,
        )

        with patch.object(classifier, "model", mock_peft_model):
            with patch(
                "app.infrastructure.ai.classifier.lora.preprocess_text",
                return_value="processed text",
            ):
                result = classifier.predict("Test text")

        assert result["source"] == "CLOUD_FALLBACK"

    @patch("app.infrastructure.ai.classifier.lora.AutoTokenizer")
    @patch("app.infrastructure.ai.classifier.lora.AutoModelForSequenceClassification")
    @patch("app.infrastructure.ai.classifier.lora.torch")
    def test_predict_non_finite_probs_raises(
        self, mock_torch, mock_auto_model, mock_tokenizer, tmp_path
    ):
        """Test predict raises RuntimeError for non-finite probabilities."""
        artifact_dir = self.create_mock_artifact_dir(tmp_path)

        mock_tokenizer_instance = MagicMock()
        mock_tokenizer.from_pretrained.return_value = mock_tokenizer_instance

        mock_inputs = MagicMock()
        mock_inputs.to.return_value = mock_inputs
        mock_tokenizer_instance.return_value = mock_inputs

        mock_base_model = MagicMock()
        mock_auto_model.from_pretrained.return_value = mock_base_model
        mock_peft_model = MagicMock()
        self.peft_mock.PeftModel.from_pretrained.return_value = mock_peft_model
        mock_peft_model.to.return_value = mock_peft_model
        mock_peft_model.eval.return_value = None

        mock_torch.isfinite.return_value.all.return_value = False

        mock_torch.device.return_value = "cpu"
        mock_torch.cuda.is_available.return_value = False

        classifier = LoRAClassifier(artifact_dir, device="cpu", local_files_only=True)

        with patch.object(classifier, "model", mock_peft_model):
            with patch(
                "app.infrastructure.ai.classifier.lora.preprocess_text",
                return_value="processed text",
            ):
                with pytest.raises(
                    RuntimeError, match="Non-finite classifier probabilities"
                ):
                    classifier.predict("Test text")

    @patch("app.infrastructure.ai.classifier.lora.AutoTokenizer")
    @patch("app.infrastructure.ai.classifier.lora.AutoModelForSequenceClassification")
    @patch("app.infrastructure.ai.classifier.lora.torch")
    def test_classify_adapts_to_domain_contract(
        self, mock_torch, mock_auto_model, mock_tokenizer, tmp_path
    ):
        """Test classify method returns ClassificationResult."""
        classifier, mock_peft_model = self._setup_predict_mocks(
            mock_torch,
            mock_auto_model,
            mock_tokenizer,
            tmp_path,
            confidence=0.95,
            index=0,
        )

        with patch.object(classifier, "model", mock_peft_model):
            with patch(
                "app.infrastructure.ai.classifier.lora.preprocess_text",
                return_value="processed text",
            ):
                result = classifier.classify("Test text")

        assert isinstance(result, ClassificationResult)
        assert result.label == sorted(CATEGORIES)[0]
        assert result.confidence == 0.95

    def test_init_with_cache_dir(self, tmp_path):
        """Test initialization with custom cache directory."""
        artifact_dir = self.create_mock_artifact_dir(tmp_path)
        cache_dir = tmp_path / "cache"

        with (
            patch("app.infrastructure.ai.classifier.lora.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.lora.AutoModelForSequenceClassification"
            ) as mock_auto_model,
            patch("app.infrastructure.ai.classifier.lora.torch") as mock_torch,
        ):
            mock_torch.device.return_value = "cpu"
            mock_torch.cuda.is_available.return_value = False
            mock_torch.inference_mode.return_value.__enter__ = Mock(return_value=None)
            mock_torch.inference_mode.return_value.__exit__ = Mock(return_value=None)

            LoRAClassifier(
                artifact_dir,
                device="cpu",
                cache_dir=cache_dir,
                local_files_only=True,
            )

            mock_auto_model.from_pretrained.assert_called_once()
            assert mock_auto_model.from_pretrained.call_args.kwargs["cache_dir"] == str(
                cache_dir
            )

    def test_init_with_local_files_only_false(self, tmp_path):
        """Test initialization with local_files_only=False."""
        artifact_dir = self.create_mock_artifact_dir(tmp_path)

        with (
            patch(
                "app.infrastructure.ai.classifier.lora.AutoTokenizer"
            ) as mock_tokenizer,
            patch(
                "app.infrastructure.ai.classifier.lora.AutoModelForSequenceClassification"
            ) as mock_auto_model,
            patch("app.infrastructure.ai.classifier.lora.torch") as mock_torch,
        ):
            mock_tokenizer.from_pretrained.return_value = MagicMock()
            mock_auto_model.from_pretrained.return_value = MagicMock()
            mock_torch.device.return_value = "cpu"
            mock_torch.cuda.is_available.return_value = False
            mock_torch.inference_mode.return_value.__enter__ = Mock(return_value=None)
            mock_torch.inference_mode.return_value.__exit__ = Mock(return_value=None)

            LoRAClassifier(
                artifact_dir,
                device="cpu",
                local_files_only=False,
            )

            # Verify local_files_only passed to base model
            mock_auto_model.from_pretrained.assert_called_once()
            call_kwargs = mock_auto_model.from_pretrained.call_args[1]
            assert call_kwargs["local_files_only"] is False
