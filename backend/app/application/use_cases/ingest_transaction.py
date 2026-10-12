"""Classify transaction text through a domain port and apply confidence policy."""

from dataclasses import dataclass

from app.domain.interfaces.asr_interface import IAudioTranscriber
from app.domain.interfaces.classifier_interface import (
    ClassificationResult,
    ITransactionClassifier,
)


@dataclass(frozen=True)
class IngestTransactionResult:
    text: str
    classification: ClassificationResult
    requires_review: bool


class IngestTransaction:
    def __init__(
        self,
        classifier: ITransactionClassifier,
        confidence_threshold: float = 0.8,
    ) -> None:
        if not 0 <= confidence_threshold <= 1:
            raise ValueError("confidence_threshold must be in [0, 1]")
        self.classifier = classifier
        self.confidence_threshold = confidence_threshold

    def execute(self, text: str) -> IngestTransactionResult:
        if not text.strip():
            raise ValueError("Transaction text must not be empty")
        classification = self.classifier.classify(text)
        return IngestTransactionResult(
            text=text,
            classification=classification,
            requires_review=classification.confidence < self.confidence_threshold,
        )

    def execute_audio(
        self,
        audio: bytes,
        transcriber: IAudioTranscriber,
        sample_rate: int = 16000,
    ) -> IngestTransactionResult:
        """Transcribe audio via the domain port before text classification."""
        return self.execute(transcriber.transcribe(audio, sample_rate))
