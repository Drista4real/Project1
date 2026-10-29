"""Strict Pydantic v2 contracts for receipt extraction and persona advice."""

from datetime import date
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.domain.interfaces.advisor_interface import AlertType
from app.domain.interfaces.vlm_interface import ReceiptData, ReceiptItem

Category = Literal["Ăn uống", "Đi lại", "Mua sắm", "Hóa đơn/Nhà ở", "Y tế", "Khác"]


class ReceiptItemSchema(BaseModel):
    """A receipt line containing a positive quantity and nonnegative unit price."""

    model_config = ConfigDict(extra="forbid", strict=True, str_strip_whitespace=True)
    name: str = Field(min_length=1)
    quantity: int = Field(default=1, ge=1)
    price: int = Field(ge=0)


class ReceiptExtractionResult(BaseModel):
    """Structured VND extraction; Python recomputes arithmetic and confidence."""

    model_config = ConfigDict(
        extra="forbid", strict=True, str_strip_whitespace=True, allow_inf_nan=False
    )
    merchant_name: str = Field(min_length=1)
    transaction_date: str | None = Field(default=None, pattern=r"^\d{4}-\d{2}-\d{2}$")
    items: list[ReceiptItemSchema]
    total_amount: int = Field(ge=0)
    category: Category
    confidence_score: float = Field(ge=0, le=1)
    is_arithmetic_valid: bool = False

    @field_validator("transaction_date")
    @classmethod
    def validate_date(cls, value: str | None) -> str | None:
        """Accept only real ISO YYYY-MM-DD dates or an explicitly unknown date."""
        if value is not None and date.fromisoformat(value).isoformat() != value:
            raise ValueError("transaction_date must use YYYY-MM-DD")
        return value

    def to_domain(self) -> ReceiptData:
        """Preserve review metadata in the framework-independent domain object."""
        return ReceiptData(
            merchant=self.merchant_name,
            total=Decimal(self.total_amount),
            issued_on=date.fromisoformat(self.transaction_date)
            if self.transaction_date
            else None,
            items=tuple(ReceiptItem(i.name, i.quantity, i.price) for i in self.items),
            category=self.category,
            confidence_score=self.confidence_score,
            is_arithmetic_valid=self.is_arithmetic_valid,
        )


class AdvisorAlertResponse(BaseModel):
    """Validated persona message and optional action."""

    model_config = ConfigDict(extra="forbid", strict=True, str_strip_whitespace=True)
    alert_type: AlertType
    message: str = Field(min_length=1, max_length=1000)
    suggested_action: str | None = Field(default=None, max_length=1000)


class ReceiptSchema(BaseModel):
    """Keep the original minimal schema usable by existing local-VLM consumers."""

    model_config = ConfigDict(extra="forbid")
    merchant: str | None
    total: Decimal = Field(ge=0)
    currency: str = Field(default="VND", min_length=3, max_length=3)
    issued_on: date | None = None

    def to_domain(self) -> ReceiptData:
        """Map the legacy receipt schema to the domain value object."""
        return ReceiptData(**self.model_dump())


def receipt_json_schema() -> dict[str, Any]:
    """Return the full receipt schema for structured-output capable backends."""
    return ReceiptExtractionResult.model_json_schema()
