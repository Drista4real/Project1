from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal, Protocol
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator

TransactionType = Literal["income", "expense", "transfer"]
Money = Annotated[Decimal, Field(gt=0, max_digits=15, decimal_places=2)]
Identifier = Annotated[int, Field(gt=0)]


class TransactionData(BaseModel):
    model_config = ConfigDict(extra="forbid")

    amount: Money
    transaction_type: TransactionType
    account_id: Identifier | None = None
    to_account_id: Identifier | None = None
    category_id: Identifier | None = None
    raw_description: str | None = Field(default=None, max_length=2000)
    clean_description: str | None = Field(default=None, max_length=2000)
    transaction_date: AwareDatetime

    @model_validator(mode="after")
    def validate_transfer(self):
        if self.transaction_type == "transfer":
            if not self.account_id or not self.to_account_id:
                raise ValueError("Transfers require source and destination accounts")
            if self.account_id == self.to_account_id:
                raise ValueError("Transfer accounts must differ")
            if self.category_id is not None:
                raise ValueError("Transfers cannot have a category")
        elif self.to_account_id is not None:
            raise ValueError("Only transfers have a destination account")
        return self


class Transaction(TransactionData):
    model_config = ConfigDict(extra="ignore")

    id: int
    user_id: UUID
    created_at: datetime
    updated_at: datetime
    categories: dict | None = None
    pillar: Literal["needs", "wants", "culture", "unexpected", "income"] | None = None


class TransactionError(Exception):
    def __init__(self, status: int, message: str):
        self.status = status
        self.message = message


class TransactionRepository(Protocol):
    def list(self, limit: int, offset: int, kind: TransactionType | None) -> dict: ...
    def get(self, transaction_id: int) -> Transaction: ...
    def create(self, data: dict) -> Transaction: ...
    def update(
        self, transaction_id: int, data: dict, updated_at: str
    ) -> Transaction: ...
    def delete(self, transaction_id: int) -> None: ...
    def account(self, account_id: int) -> dict | None: ...
    def category(self, category_id: int) -> dict | None: ...
