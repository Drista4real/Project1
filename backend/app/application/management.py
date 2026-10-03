from pydantic import ValidationError

from app.domain.management import RESOURCES, ManagementRepository
from app.domain.transactions import TransactionError


class ManagementService:
    def __init__(self, repository: ManagementRepository):
        self.repository = repository

    def require(self, resource: str):
        if resource not in RESOURCES:
            raise TransactionError(404, "Unknown resource")
        return RESOURCES[resource][1]

    def list(self, resource: str, limit: int, offset: int):
        self.require(resource)
        return self.repository.list(resource, limit, offset)

    def get(self, resource: str, key: str):
        self.require(resource)
        self.check_key(resource, key)
        return self.repository.get(resource, key)

    @staticmethod
    def check_key(resource: str, key: str):
        if resource == "profile":
            if key != "me":
                raise TransactionError(404, "Record not found")
            return
        parts = key.split(":")
        if len(parts) != (2 if resource == "transaction_tags" else 1):
            raise TransactionError(422, "Invalid record identifier")
        if any(
            not part.isascii()
            or not part.isdigit()
            or not 0 < int(part) <= 9223372036854775807
            for part in parts
        ):
            raise TransactionError(422, "Invalid record identifier")

    def writable(self, resource: str, record: dict):
        if (
            resource == "categories"
            and record.get("user_id") != self.repository.user_id
        ):
            raise TransactionError(403, "Danh mục hệ thống chỉ được xem.")

    def validate(self, resource: str, data: dict, key: str | None = None):
        model = self.require(resource)
        try:
            validated = model.model_validate(data).model_dump(mode="json")
        except ValidationError as error:
            # Only schema messages; never echo stored data or credentials.
            messages = [
                f"{'.'.join(map(str, e['loc']))}: {e['msg']}" for e in error.errors()
            ]
            raise TransactionError(422, "; ".join(messages)) from error
        references = {
            "account_id": "accounts",
            "category_id": "categories",
            "parent_id": "categories",
            "session_id": "ai_chat_sessions",
            "transaction_id": "transactions",
            "tag_id": "tags",
        }
        for field, target in references.items():
            value = validated.get(field)
            if value is None:
                continue
            try:
                related = self.repository.get(target, str(value))
            except TransactionError as error:
                raise TransactionError(
                    422,
                    f"{field}: dữ liệu không tồn tại hoặc không thuộc về bạn.",
                ) from error
            if target == "accounts" and related.get("is_archived"):
                # Allow unchanged archived references on existing historical records.
                current = self.repository.get(resource, key) if key else {}
                if current.get(field) != value:
                    raise TransactionError(422, "Vui lòng chọn ví chưa lưu trữ.")
            if target == "categories":
                expected_income = validated.get("transaction_type") == "income"
                if resource == "categories":
                    expected_income = validated["is_income"]
                if resource in {"categories", "budgets", "recurring_transactions"}:
                    if related.get("is_income") != expected_income:
                        raise TransactionError(
                            422, "Danh mục phải khớp loại thu nhập hoặc chi tiêu."
                        )
        if resource == "categories" and validated.get("parent_id"):
            seen = {int(key)} if key else set()
            parent = validated["parent_id"]
            while parent:
                if parent in seen:
                    raise TransactionError(422, "Danh mục cha tạo thành vòng lặp.")
                seen.add(parent)
                parent = self.repository.get("categories", str(parent)).get("parent_id")
        return validated

    def create(self, resource: str, data: dict):
        self.require(resource)
        if resource == "profile":
            raise TransactionError(405, "Profiles are created by authentication")
        return self.repository.create(resource, self.validate(resource, data))

    def update(self, resource: str, key: str, patch: dict):
        current = self.get(resource, key)
        self.writable(resource, current)
        fields = self.require(resource).model_fields
        if not patch or patch.keys() - fields.keys():
            raise TransactionError(422, "Supply editable fields only")
        merged = {field: current[field] for field in fields if field in current}
        merged.update(patch)
        valid = self.validate(resource, merged, key)
        if resource == "categories" and valid["is_income"] != current["is_income"]:
            for table in (
                "transactions",
                "recurring_transactions",
                "budgets",
                "categories",
            ):
                column = "parent_id" if table == "categories" else "category_id"
                if self.repository.referenced(table, column, int(key)):
                    raise TransactionError(
                        409, "Danh mục đang được sử dụng, không thể đổi loại thu chi."
                    )
        return self.repository.update(
            resource, key, {field: valid[field] for field in patch}
        )

    def delete(self, resource: str, key: str):
        current = self.get(resource, key)
        self.writable(resource, current)
        if resource == "profile":
            raise TransactionError(
                405, "Profile lifecycle is managed by authentication"
            )
        dependencies = {
            "accounts": [
                ("transactions", "account_id"),
                ("transactions", "to_account_id"),
                ("saving_goals", "account_id"),
                ("recurring_transactions", "account_id"),
            ],
            "categories": [
                ("transactions", "category_id"),
                ("budgets", "category_id"),
                ("recurring_transactions", "category_id"),
                ("categories", "parent_id"),
            ],
        }
        for table, column in dependencies.get(resource, []):
            if self.repository.referenced(table, column, int(key)):
                raise TransactionError(
                    409, "Dữ liệu đang được sử dụng. Hãy gỡ liên kết hoặc lưu trữ ví."
                )
        self.repository.delete(resource, key)
