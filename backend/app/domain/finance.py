from typing import Protocol

from pydantic import BaseModel


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
