"""Tests for the chat repository's fallback when a migration is missing.

The slot columns and the tool trace arrive with migration 202611010002.
Until it is applied the conversation must still work: only the collected
slots and the audit trail are unavailable.
"""

from unittest.mock import Mock

import pytest
from postgrest.exceptions import APIError

from app.infrastructure.repositories.chat import SupabaseChatRepository


def _missing_column_error() -> APIError:
    """The error PostgREST raises for a column that does not exist."""
    return APIError(
        {
            "code": "42703",
            "message": "column ai_chat_messages.tool_name does not exist",
        }
    )


class _Query:
    """A chainable PostgREST query double."""

    def __init__(self, result=None, error=None):
        self.result = result
        self.error = error
        self.selected: list[str] = []
        self.inserted: list[dict] = []
        self.updates: list[dict] = []

    def select(self, columns, **kwargs):
        self.selected.append(columns)
        return self

    def eq(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def range(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def insert(self, payload):
        self.inserted.append(payload)
        return self

    def update(self, payload):
        self.updates.append(payload)
        return self

    def execute(self):
        if self.error is not None:
            error = self.error
            self.error = None
            raise error
        return self.result


class _Client:
    """A Supabase client double that hands out prepared queries."""

    def __init__(self, queries):
        self.queries = list(queries)
        self.requested: list[str] = []

    def table(self, name):
        self.requested.append(name)
        return self.queries.pop(0)


def _result(data):
    result = Mock()
    result.data = data
    result.count = len(data)
    return result


class TestMissingMigration:
    """The repository degrades instead of failing."""

    def setup_method(self):
        self.user_id = "user-1"

    def test_the_session_is_read_without_the_slot_columns(self):
        query = _Query(
            error=_missing_column_error(),
            result=_result([{"id": 1, "title": "Test"}]),
        )
        client = _Client([query, query])
        repository = SupabaseChatRepository(client, self.user_id)

        session = repository.session(1)

        assert session.id == 1
        assert session.slots.total_income is None
        # The first read asked for the slots, the second did not.
        assert "budget_slots" in query.selected[0]
        assert "budget_slots" not in query.selected[1]

    def test_the_messages_are_read_without_the_tool_trace(self):
        query = _Query(
            error=_missing_column_error(),
            result=_result(
                [{"id": 5, "session_id": 1, "sender": "user", "content": "Hi"}]
            ),
        )
        client = _Client([query, query])
        repository = SupabaseChatRepository(client, self.user_id)

        messages = repository.messages(1, 50)

        assert len(messages) == 1
        assert messages[0].content == "Hi"
        assert messages[0].tool_name is None

    def test_a_message_is_stored_without_the_tool_trace(self):
        query = _Query(
            error=_missing_column_error(),
            result=_result(
                [{"id": 6, "session_id": 1, "sender": "user", "content": "Hi"}]
            ),
        )
        client = _Client([query, query])
        repository = SupabaseChatRepository(client, self.user_id)

        message = repository.append_message(1, "user", "Hi")

        assert message.id == 6
        # The first insert carried the trace, the second only the message.
        assert "tool_name" not in query.inserted[0]
        assert "tool_name" not in query.inserted[1]

    def test_the_slots_are_dropped_instead_of_failing(self):
        query = _Query(error=_missing_column_error())
        client = _Client([query])
        repository = SupabaseChatRepository(client, self.user_id)

        from app.domain.chat import BudgetSlots

        repository.save_slots(1, BudgetSlots(total_income="1000"))

    def test_another_database_error_is_not_swallowed(self):
        query = _Query(error=APIError({"code": "42501", "message": "denied"}))
        client = _Client([query])
        repository = SupabaseChatRepository(client, self.user_id)

        with pytest.raises(APIError):
            repository.messages(1, 50)
