from pydantic import ValidationError

from app.domain.transactions import (
    TransactionData,
    TransactionError,
    TransactionRepository,
)


class TransactionService:
    def __init__(self, repository: TransactionRepository):
        self.repository = repository

    def _validate_references(self, data: TransactionData):
        for account_id in (data.account_id, data.to_account_id):
            if account_id is not None:
                account = self.repository.account(account_id)
                if account is None or account["is_archived"]:
                    raise TransactionError(422, "Account is unavailable")
        if data.category_id is not None:
            category = self.repository.category(data.category_id)
            if category is None:
                raise TransactionError(422, "Category is unavailable")
            if category["is_income"] != (data.transaction_type == "income"):
                raise TransactionError(422, "Category does not match transaction type")

    def create(self, data: TransactionData):
        self._validate_references(data)
        return self.repository.create(data.model_dump(mode="json"))

    def update(self, transaction_id: int, changes: dict):
        current = self.repository.get(transaction_id)
        merged = current.model_dump(include=set(TransactionData.model_fields))
        merged.update(changes)
        try:
            validated = TransactionData.model_validate(merged)
        except ValidationError as error:
            raise TransactionError(422, "Invalid transaction fields") from error
        self._validate_references(validated)
        # Write only supplied fields, and reject an intervening modification.
        payload = validated.model_dump(mode="json", include=set(changes))
        return self.repository.update(
            transaction_id, payload, current.updated_at.isoformat()
        )
