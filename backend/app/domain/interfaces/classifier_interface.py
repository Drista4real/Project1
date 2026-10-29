"""Domain contract and result for transaction classification."""

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True)
class ClassificationResult:
    label: str
    confidence: float


class ITransactionClassifier(Protocol):
    def classify(self, text: str) -> ClassificationResult:
        """Predict a category and its probability for a transaction description."""
        ...
