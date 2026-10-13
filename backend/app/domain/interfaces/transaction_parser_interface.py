"""Pure-domain contract for a transaction draft that still needs confirmation."""

from dataclasses import dataclass
from typing import Literal, Protocol


@dataclass(frozen=True)
class TransactionDraft:
    """Extracted input, never a persisted transaction or a balance calculation."""

    text: str
    normalized_text: str
    amount: int | None
    transaction_type: Literal["expense", "income", "transfer"]
    category: str | None
    confidence: float
    source: Literal["LOCAL", "GEMINI", "RULES", "UNAVAILABLE"]
    warnings: tuple[str, ...] = ()


class ITransactionParser(Protocol):
    """Parse text without saving it or modifying financial balances."""

    async def parse(self, text: str) -> TransactionDraft:
        """Return a draft for human review."""
        ...

    async def parse_many(self, text: str) -> tuple[TransactionDraft, ...]:
        """Split and classify a bounded batch without modifying balances."""
        ...
