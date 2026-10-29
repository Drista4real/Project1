"""Tests for ingest_transaction use case."""

from unittest.mock import Mock

import pytest

from app.application.use_cases.ingest_transaction import (
    IngestTransaction,
    IngestTransactionResult,
)
from app.domain.interfaces.asr_interface import IAudioTranscriber
from app.domain.interfaces.classifier_interface import (
    ClassificationResult,
    ITransactionClassifier,
)


class TestIngestTransaction:
    """Tests for IngestTransaction use case."""

    def setup_method(self):
        self.mock_classifier = Mock(spec=ITransactionClassifier)
        self.use_case = IngestTransaction(
            classifier=self.mock_classifier, confidence_threshold=0.8
        )

    def test_init_default_confidence_threshold(self):
        """Test initialization with default confidence threshold."""
        use_case = IngestTransaction(classifier=self.mock_classifier)
        assert use_case.confidence_threshold == 0.8

    def test_init_custom_confidence_threshold(self):
        """Test initialization with custom confidence threshold."""
        use_case = IngestTransaction(
            classifier=self.mock_classifier, confidence_threshold=0.9
        )
        assert use_case.confidence_threshold == 0.9

    def test_init_invalid_confidence_threshold_negative(self):
        """Test initialization with negative confidence threshold raises ValueError."""
        with pytest.raises(
            ValueError, match="confidence_threshold must be in \\[0, 1\\]"
        ):
            IngestTransaction(
                classifier=self.mock_classifier, confidence_threshold=-0.1
            )

    def test_init_invalid_confidence_threshold_above_one(self):
        """Test initialization with confidence threshold > 1 raises ValueError."""
        with pytest.raises(
            ValueError, match="confidence_threshold must be in \\[0, 1\\]"
        ):
            IngestTransaction(classifier=self.mock_classifier, confidence_threshold=1.1)

    def test_execute_valid_text(self):
        """Test execute with valid text."""
        classification = ClassificationResult(label="Ăn uống", confidence=0.9)
        self.mock_classifier.classify.return_value = classification

        result = self.use_case.execute("Mua đồ ăn 50000 đồng")

        assert isinstance(result, IngestTransactionResult)
        assert result.text == "Mua đồ ăn 50000 đồng"
        assert result.classification == classification
        assert result.requires_review is False  # confidence >= threshold

    def test_execute_requires_review_low_confidence(self):
        """Test execute marks requires_review when confidence below threshold."""
        classification = ClassificationResult(label="Ăn uống", confidence=0.5)
        self.mock_classifier.classify.return_value = classification

        result = self.use_case.execute("Mua đồ ăn 50000 đồng")

        assert result.requires_review is True  # confidence < threshold

    def test_execute_empty_text_raises(self):
        """Test execute raises ValueError for empty text."""
        with pytest.raises(ValueError, match="Transaction text must not be empty"):
            self.use_case.execute("")

    def test_execute_whitespace_only_text_raises(self):
        """Test execute raises ValueError for whitespace-only text."""
        with pytest.raises(ValueError, match="Transaction text must not be empty"):
            self.use_case.execute("   \n\t  ")

    def test_execute_audio(self):
        """Test execute_audio transcribes audio then classifies."""
        mock_transcriber = Mock(spec=IAudioTranscriber)
        mock_transcriber.transcribe.return_value = "Mua đồ ăn 50000 đồng"

        classification = ClassificationResult(label="Ăn uống", confidence=0.9)
        self.mock_classifier.classify.return_value = classification

        result = self.use_case.execute_audio(
            audio=b"fake_audio_data",
            transcriber=mock_transcriber,
            sample_rate=16000,
        )

        assert isinstance(result, IngestTransactionResult)
        assert result.text == "Mua đồ ăn 50000 đồng"
        mock_transcriber.transcribe.assert_called_once_with(b"fake_audio_data", 16000)

    def test_execute_audio_custom_sample_rate(self):
        """Test execute_audio with custom sample rate."""
        mock_transcriber = Mock(spec=IAudioTranscriber)
        mock_transcriber.transcribe.return_value = "Mua đồ ăn 50000 đồng"
        self.mock_classifier.classify.return_value = ClassificationResult(
            label="Ăn uống", confidence=0.9
        )

        self.use_case.execute_audio(
            audio=b"fake_audio_data",
            transcriber=mock_transcriber,
            sample_rate=44100,
        )

        mock_transcriber.transcribe.assert_called_once_with(b"fake_audio_data", 44100)

    def test_execute_calls_classifier_with_correct_text(self):
        """Test that execute passes the exact text to classifier."""
        test_text = "Test transaction text"
        self.mock_classifier.classify.return_value = ClassificationResult(
            label="Khác", confidence=0.8
        )

        self.use_case.execute(test_text)

        self.mock_classifier.classify.assert_called_once_with(test_text)
