from postgrest.exceptions import APIError
from supabase import Client

from app.domain.transactions import TransactionError


class SupabaseManagementRepository:
    """Table names come exclusively from the application's fixed registry."""

    def __init__(self, client: Client, user_id: str):
        self.client = client
        self.user_id = user_id

    def query(self, resource: str, *, write: bool = False, count: bool = False):
        table = "profiles" if resource == "profile" else resource
        columns = "*"
        if resource == "ai_chat_messages":
            columns += ",ai_chat_sessions!inner(user_id)"
        if resource == "transaction_tags":
            columns += ",transactions!inner(user_id)"
        query = self.client.table(table).select(
            columns, count="exact" if count else None
        )
        return self.scope(query, resource, write=write)

    def scope(self, query, resource: str, *, write: bool = False):
        if resource == "profile":
            return query.eq("id", self.user_id)
        if resource == "categories" and not write:
            return query.or_(f"user_id.is.null,user_id.eq.{self.user_id}")
        if resource == "ai_chat_messages":
            return query.eq("ai_chat_sessions.user_id", self.user_id)
        if resource == "transaction_tags":
            return query.eq("transactions.user_id", self.user_id)
        return query.eq("user_id", self.user_id)

    @staticmethod
    def identify(query, resource: str, key: str):
        if resource == "profile":
            return query
        if resource == "transaction_tags":
            transaction_id, tag_id = key.split(":")
            return query.eq("transaction_id", int(transaction_id)).eq(
                "tag_id", int(tag_id)
            )
        return query.eq("id", int(key))

    def list(self, resource: str, limit: int, offset: int) -> dict:
        column = "transaction_id" if resource == "transaction_tags" else "id"
        query = self.query(resource, count=True).order(column, desc=True)
        if resource == "transaction_tags":
            query = query.order("tag_id", desc=True)
        try:
            result = query.range(offset, offset + limit - 1).execute()
            items = result.data
        except APIError as error:
            if error.code != "PGRST103" or offset == 0:
                raise
            # Keep the same ownership scope, including parent joins, when
            # counting an empty page beyond the end of the collection.
            result = self.query(resource, count=True).limit(0).execute()
            items = []
        return {
            "items": items,
            "total": result.count or 0,
            "limit": limit,
            "offset": offset,
        }

    def get(self, resource: str, key: str) -> dict:
        result = self.identify(self.query(resource), resource, key).execute()
        if not result.data:
            raise TransactionError(404, "Record not found")
        return result.data[0]

    def create(self, resource: str, data: dict) -> dict:
        if resource not in {"ai_chat_messages", "transaction_tags"}:
            data = {**data, "user_id": self.user_id}
        result = self.client.table(resource).insert(data).execute()
        if not result.data:
            raise TransactionError(409, "Unable to create record")
        return result.data[0]

    def mutation(self, resource: str, key: str, data: dict | None):
        # Parent ownership was checked by the service; RLS rechecks it atomically.
        table = "profiles" if resource == "profile" else resource
        query = self.client.table(table)
        query = query.delete() if data is None else query.update(data)
        if resource not in {"ai_chat_messages", "transaction_tags"}:
            query = self.scope(query, resource, write=True)
        result = self.identify(query, resource, key).execute()
        if not result.data:
            raise TransactionError(404, "Record not found")
        return result.data[0]

    def update(self, resource: str, key: str, data: dict) -> dict:
        return self.mutation(resource, key, data)

    def delete(self, resource: str, key: str) -> None:
        self.mutation(resource, key, None)

    def referenced(self, table: str, column: str, value: int) -> bool:
        return bool(self.query(table).eq(column, value).limit(1).execute().data)
