from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Query, Response
from pydantic import AwareDatetime, BaseModel, ConfigDict, Field, model_validator

from app.api.dependencies import ServiceDependency
from app.domain.transactions import (
    Identifier,
    Money,
    Transaction,
    TransactionData,
    TransactionType,
)

router = APIRouter(prefix="/api/v1/transactions", tags=["Transactions"])


class CreateTransaction(TransactionData):
    transaction_date: AwareDatetime = Field(default_factory=lambda: datetime.now(UTC))


class UpdateTransaction(BaseModel):
    model_config = ConfigDict(extra="forbid")
    amount: Money | None = None
    transaction_type: TransactionType | None = None
    account_id: Identifier | None = None
    to_account_id: Identifier | None = None
    category_id: Identifier | None = None
    raw_description: str | None = Field(default=None, max_length=2000)
    clean_description: str | None = Field(default=None, max_length=2000)
    transaction_date: AwareDatetime | None = None

    @model_validator(mode="after")
    def validate_patch(self):
        if not self.model_fields_set:
            raise ValueError("Provide at least one field")
        for name in ("amount", "transaction_type", "transaction_date"):
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"{name} cannot be null")
        return self


class TransactionPage(BaseModel):
    items: list[Transaction]
    total: int
    limit: int
    offset: int


@router.get("", response_model=TransactionPage)
def list_transactions(
    service: ServiceDependency,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
    offset: Annotated[int, Query(ge=0)] = 0,
    transaction_type: TransactionType | None = None,
):
    return service.repository.list(limit, offset, transaction_type)


@router.post("", response_model=Transaction, status_code=201)
def create_transaction(data: CreateTransaction, service: ServiceDependency):
    return service.create(data)


@router.get("/{transaction_id}", response_model=Transaction)
def get_transaction(transaction_id: Identifier, service: ServiceDependency):
    return service.repository.get(transaction_id)


@router.patch("/{transaction_id}", response_model=Transaction)
def update_transaction(
    transaction_id: Identifier, data: UpdateTransaction, service: ServiceDependency
):
    return service.update(transaction_id, data.model_dump(exclude_unset=True))


@router.delete("/{transaction_id}", status_code=204)
def delete_transaction(transaction_id: Identifier, service: ServiceDependency):
    service.repository.delete(transaction_id)
    return Response(status_code=204)
