"""Unit tests for PhoBERT embedder."""

from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from app.infrastructure.ai.classifier.config import MODEL_CACHE_DIR, ClassifierConfig
from app.infrastructure.ai.classifier.phobert_embedder import PhoBERTEmbedder


class TestPhoBERTEmbedder:
    """Tests for PhoBERTEmbedder class."""

    def test_init_with_defaults(self) -> None:
        """Test initialization with default parameters."""
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=768)
            )
            embedder = PhoBERTEmbedder(local_files_only=True)
            assert embedder.config.model_name == "vinai/phobert-base"
            assert embedder.cache_dir == MODEL_CACHE_DIR

    def test_init_with_custom_config(self) -> None:
        """Test initialization with custom config."""
        config = ClassifierConfig(revision="custom_rev")
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=768)
            )
            embedder = PhoBERTEmbedder(config=config, local_files_only=True)
            assert embedder.config.revision == "custom_rev"

    def test_init_with_custom_cache_dir(self, tmp_path: Path) -> None:
        """Test initialization with custom cache directory."""
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=768)
            )
            embedder = PhoBERTEmbedder(
                cache_dir=tmp_path / "custom_cache", local_files_only=True
            )
            assert embedder.cache_dir == tmp_path / "custom_cache"

    def test_load_local_files_only_success(self) -> None:
        """Test loading with local_files_only=True succeeds."""
        with (
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"
            ) as mock_tokenizer,
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_tokenizer.from_pretrained.return_value = MagicMock()
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=768)
            )

            PhoBERTEmbedder(local_files_only=True)
            mock_tokenizer.from_pretrained.assert_called_once()
            mock_model.from_pretrained.assert_called_once()

    def test_load_fallback_to_remote(self) -> None:
        """Test fallback to remote when local files not found."""
        with (
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"
            ) as mock_tokenizer,
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            # Create mock objects that will be returned on the second call
            mock_tokenizer_remote = MagicMock()
            mock_model_remote = MagicMock(config=MagicMock(hidden_size=768))

            # First _load(local_files_only=True): tokenizer raises OSError, model not
            # reached
            # Second _load(local_files_only=False): tokenizer returns mock, model
            # returns mock
            mock_tokenizer.from_pretrained.side_effect = [
                OSError("Not found"),
                mock_tokenizer_remote,
            ]
            mock_model.from_pretrained.side_effect = [
                mock_model_remote
            ]  # Only called once (during second _load)

            PhoBERTEmbedder(local_files_only=False)
            assert mock_tokenizer.from_pretrained.call_count == 2
            assert mock_model.from_pretrained.call_count == 1

    def test_load_fails_when_local_only_and_missing(self) -> None:
        """Test that local_files_only=True fails when files missing."""
        with (
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"
            ) as mock_tokenizer,
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoModel"),
        ):
            mock_tokenizer.from_pretrained.side_effect = OSError("Not found")

            with pytest.raises(RuntimeError, match="Cannot load PhoBERT"):
                PhoBERTEmbedder(local_files_only=True)

    def test_invalid_hidden_size(self) -> None:
        """Test that wrong hidden size raises ValueError."""
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=512)
            )

            with pytest.raises(ValueError, match="PhoBERT hidden size must be 768"):
                PhoBERTEmbedder(local_files_only=True)

    def test_embed_single_text(self) -> None:
        """Test embedding a single text."""
        with (
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"
            ) as mock_tokenizer,
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_tokenizer_instance = MagicMock()
            mock_tokenizer_instance.return_value = {
                "input_ids": MagicMock(),
                "attention_mask": MagicMock(),
            }
            mock_tokenizer.from_pretrained.return_value = mock_tokenizer_instance

            mock_model_instance = MagicMock()
            mock_model_instance.config.hidden_size = 768

            # Create a proper mock for the model output that handles tensor slicing
            mock_last_hidden = MagicMock()
            mock_sliced = MagicMock()
            mock_sliced.cpu.return_value.numpy.return_value = (
                np.random.default_rng(42).random((1, 768)).astype(np.float32)
            )
            mock_last_hidden.__getitem__.return_value = mock_sliced

            mock_output = MagicMock()
            mock_output.last_hidden_state = mock_last_hidden
            mock_model_instance.return_value = (
                mock_output  # Use return_value for callable mock
            )
            mock_model.from_pretrained.return_value = mock_model_instance

            embedder = PhoBERTEmbedder(local_files_only=True)
            result = embedder.embed("test text")

            assert isinstance(result, np.ndarray)
            assert result.shape == (768,)
            assert result.dtype == np.float32

    def test_embed_batch_multiple_texts(self) -> None:
        """Test embedding multiple texts."""
        with (
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"
            ) as mock_tokenizer,
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_tokenizer_instance = MagicMock()
            mock_tokenizer_instance.return_value = {
                "input_ids": MagicMock(),
                "attention_mask": MagicMock(),
            }
            mock_tokenizer.from_pretrained.return_value = mock_tokenizer_instance

            mock_model_instance = MagicMock()
            mock_model_instance.config.hidden_size = 768

            # Create a proper mock for the model output that handles tensor slicing
            # The code processes in batches, so we need to handle multiple calls
            call_count = [0]

            def mock_call(*args, **kwargs):
                call_count[0] += 1
                batch_size = (
                    2 if call_count[0] == 1 else 1
                )  # First batch 2, second batch 1
                mock_last_hidden = MagicMock()
                mock_sliced = MagicMock()
                mock_sliced.cpu.return_value.numpy.return_value = (
                    np.random.default_rng(42)
                    .random((batch_size, 768))
                    .astype(np.float32)
                )
                mock_last_hidden.__getitem__.return_value = mock_sliced
                mock_output = MagicMock()
                mock_output.last_hidden_state = mock_last_hidden
                return mock_output

            mock_model_instance.side_effect = (
                mock_call  # Use side_effect for callable mock
            )
            mock_model.from_pretrained.return_value = mock_model_instance

            embedder = PhoBERTEmbedder(local_files_only=True)
            result = embedder.embed_batch(["text1", "text2", "text3"], batch_size=2)

            assert isinstance(result, np.ndarray)
            assert result.shape == (3, 768)
            assert result.dtype == np.float32

    def test_embed_batch_invalid_input_type(self) -> None:
        """Test that string input to embed_batch raises TypeError."""
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=768)
            )
            embedder = PhoBERTEmbedder(local_files_only=True)

            with pytest.raises(
                TypeError, match="embed_batch expects a sequence of strings"
            ):
                embedder.embed_batch("not a list")  # type: ignore

    def test_embed_batch_invalid_batch_size(self) -> None:
        """Test that batch_size < 1 raises ValueError."""
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=768)
            )
            embedder = PhoBERTEmbedder(local_files_only=True)

            with pytest.raises(ValueError, match="batch_size must be positive"):
                embedder.embed_batch(["text1"], batch_size=0)

    def test_embed_batch_empty_list(self) -> None:
        """Test embedding empty list returns empty array."""
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model.from_pretrained.return_value = MagicMock(
                config=MagicMock(hidden_size=768)
            )
            embedder = PhoBERTEmbedder(local_files_only=True)
            result = embedder.embed_batch([])

            assert isinstance(result, np.ndarray)
            assert result.shape == (0, 768)

    def test_model_eval_mode(self) -> None:
        """Test that model is set to eval mode."""
        with (
            patch("app.infrastructure.ai.classifier.phobert_embedder.AutoTokenizer"),
            patch(
                "app.infrastructure.ai.classifier.phobert_embedder.AutoModel"
            ) as mock_model,
        ):
            mock_model_instance = MagicMock()
            mock_model_instance.config.hidden_size = 768
            mock_model.from_pretrained.return_value = mock_model_instance

            PhoBERTEmbedder(local_files_only=True)
            mock_model_instance.eval.assert_called_once()
            mock_model_instance.to.assert_called_with("cpu")
