from decimal import Decimal
from typing import Protocol

from pydantic import BaseModel, ConfigDict, Field


class AccountSummary(BaseModel):
    id: int
    name: str
    balance: str | float
    currency: str


class CategorySummary(BaseModel):
    id: int
    name: str
    icon: str
    color: str
    is_income: bool
    pillar: str | None


class FinancialOverview(BaseModel):
    current_balance: str
    monthly_income: str
    monthly_expense: str


class FinanceQueries(Protocol):
    def accounts(self) -> list[dict]: ...
    def categories(self) -> list[dict]: ...
    def overview(self) -> dict: ...
    def included_wallets(self) -> list[dict]: ...
    def set_wallet_balance(self, wallet_id: int, balance: Decimal) -> None: ...
    def create_wallet(self, balance: Decimal) -> None: ...


class BalanceUpdate(BaseModel):
    """The single available balance the user states."""

    model_config = ConfigDict(extra="forbid")

    amount: Decimal = Field(ge=0, max_digits=15, decimal_places=2)


class BalanceResult(BaseModel):
    current_balance: Decimal
