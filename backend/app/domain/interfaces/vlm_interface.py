"""Domain contract and vendor-neutral receipt extraction result."""

from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Protocol


@dataclass(frozen=True)
class ReceiptItem:
    """Vendor-neutral item amounts in integer VND."""

    name: str
    quantity: int
    price: int


@dataclass(frozen=True)
class ReceiptData:
    merchant: str | None
    total: Decimal
    currency: str = "VND"
    issued_on: date | None = None
    items: tuple[ReceiptItem, ...] = ()
    category: str | None = None
    confidence_score: float = 0.0
    is_arithmetic_valid: bool = False


class IReceiptExtractor(Protocol):
    async def extract(self, image: bytes, mime_type: str = "image/jpeg") -> ReceiptData:
        """Extract a validated receipt from document image bytes."""
        ...
