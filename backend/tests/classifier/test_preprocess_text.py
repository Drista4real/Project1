"""Unit tests for Vietnamese text preprocessing."""

import pytest

from app.infrastructure.ai.classifier.phobert_embedder import preprocess_text


class TestPreprocessText:
    """Tests for preprocess_text function."""

    def test_normal_text(self) -> None:
        """Test normal Vietnamese text preprocessing."""
        result = preprocess_text("Chi tiêu ăn uống")
        assert isinstance(result, str)
        assert len(result) > 0

    def test_uppercase_text(self) -> None:
        """Test that uppercase text is lowercased."""
        result = preprocess_text("CHI TIÊU ĂN UỐNG")
        assert result == result.lower()

    def test_extra_whitespace(self) -> None:
        """Test that extra whitespace is normalized."""
        result = preprocess_text("  chi   tiêu  ăn uống  ")
        assert "  " not in result  # No double spaces
        assert not result.startswith(" ")
        assert not result.endswith(" ")

    def test_vietnamese_compound_words(self) -> None:
        """Test Vietnamese word segmentation with underthesea."""
        result = preprocess_text("ăn uống")
        # underthesea should segment compound words
        assert "ăn" in result or "uống" in result

    def test_non_string_input(self) -> None:
        """Test that non-string input raises TypeError."""
        with pytest.raises(TypeError, match="Transaction text must be a string"):
            preprocess_text(123)  # type: ignore

    def test_empty_string(self) -> None:
        """Test that empty string raises ValueError."""
        with pytest.raises(ValueError, match="Transaction text must not be empty"):
            preprocess_text("")

    def test_whitespace_only(self) -> None:
        """Test that whitespace-only string raises ValueError after normalization."""
        with pytest.raises(ValueError, match="Transaction text must not be empty"):
            preprocess_text("   ")

    def test_special_characters(self) -> None:
        """Test handling of special characters."""
        result = preprocess_text("chi tiêu: ăn uống - 100k!")
        assert isinstance(result, str)
        assert len(result) > 0

    def test_numbers_in_text(self) -> None:
        """Test text with numbers."""
        result = preprocess_text("mua 2 cái áo 500k")
        assert "2" in result or "hai" in result  # number preserved or converted
        assert "500k" in result or "500" in result
