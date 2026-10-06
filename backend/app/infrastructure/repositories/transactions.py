from postgrest.exceptions import APIError
from supabase import Client

from app.domain.transactions import Transaction, TransactionError, TransactionType


class SupabaseTransactionRepository:
    columns = "*, categories(name)"

    def __init__(self, client: Client, user_id: str):
        self.client = client
        self.user_id = user_id

    def list(self, limit: int, offset: int, kind: TransactionType | None) -> dict:
        query = self.client.table("transactions").select(self.columns, count="exact")
        query = query.eq("user_id", self.user_id)
        if kind:
            query = query.eq("transaction_type", kind)
        try:
            result = (
                query.order("transaction_date", desc=True)
                .order("id", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
            )
            items = result.data
        except APIError as error:
            if error.code != "PGRST103" or offset == 0:
                raise
            # PostgREST returns 416 for an offset past the last row. Recount
            # with a fresh query: range() mutates the original query builder.
            count_query = (
                self.client.table("transactions")
                .select("id", count="exact", head=True)
                .eq("user_id", self.user_id)
            )
            if kind:
                count_query = count_query.eq("transaction_type", kind)
            result = count_query.execute()
            items = []
        return {
            "items": items,
            "total": result.count or 0,
            "limit": limit,
            "offset": offset,
        }

    def get(self, transaction_id: int) -> Transaction:
        result = (
            self.client.table("transactions")
            .select(self.columns)
            .eq("user_id", self.user_id)
            .eq("id", transaction_id)
            .execute()
        )
        if not result.data:
            raise TransactionError(404, "Transaction not found")
        return Transaction.model_validate(result.data[0])

    def create(self, data: dict) -> Transaction:
        result = (
            self.client.table("transactions")
            .insert({**data, "user_id": self.user_id})
            .execute()
        )
        return self.get(result.data[0]["id"])

    def update(self, transaction_id: int, data: dict, updated_at: str) -> Transaction:
        result = (
            self.client.table("transactions")
            .update(data)
            .eq("user_id", self.user_id)
            .eq("id", transaction_id)
            .eq("updated_at", updated_at)
            .execute()
        )
        if not result.data:
            raise TransactionError(409, "Transaction changed; reload before editing")
        return self.get(transaction_id)

    def delete(self, transaction_id: int) -> None:
        result = (
            self.client.table("transactions")
            .delete()
            .eq("user_id", self.user_id)
            .eq("id", transaction_id)
            .execute()
        )
        if not result.data:
            raise TransactionError(404, "Transaction not found")

    def account(self, account_id: int) -> dict | None:
        result = (
            self.client.table("accounts")
            .select("id, is_archived")
            .eq("user_id", self.user_id)
            .eq("id", account_id)
            .execute()
        )
        return result.data[0] if result.data else None

    def category(self, category_id: int) -> dict | None:
        result = (
            self.client.table("categories")
            .select("id, is_income")
            .or_(f"user_id.is.null,user_id.eq.{self.user_id}")
            .eq("id", category_id)
            .execute()
        )
        return result.data[0] if result.data else None
