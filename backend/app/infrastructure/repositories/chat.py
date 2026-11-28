"""Supabase persistence for conversations, their slots and their tool trace.

Every read and write is scoped to the authenticated owner. The agent may
append messages and store the slots it collected (ADR 0010); it never writes
generated finance data (ADR 0001).
"""

import logging
import re
from datetime import UTC, datetime
from typing import Any

from postgrest.exceptions import APIError
from supabase import Client

from app.domain.chat import (
    QUESTION_TOOL,
    BudgetSlots,
    ChatError,
    ChatMessage,
    ChatQuestion,
    ChatQuestionOption,
    ChatSession,
    Sender,
)

logger = logging.getLogger(__name__)

_SLOT_COLUMNS = "budget_slots, budget_slots_updated_at"
_SESSION_COLUMNS = f"id, title, created_at, updated_at, {_SLOT_COLUMNS}"
_LEGACY_SESSION_COLUMNS = "id, title, created_at, updated_at"

_MESSAGE_COLUMNS = (
    "id, session_id, sender, content, tool_name, tool_args, tool_result, created_at"
)
_LEGACY_MESSAGE_COLUMNS = "id, session_id, sender, content, created_at"

#: PostgREST reports a missing column with 42703 and a missing relation with
#: PGRST204. Both mean the migration has not been applied yet.
_MISSING_COLUMN_CODES = {"42703", "PGRST204"}


def _strip_number(question: str) -> str:
    """Remove a number the model put in front of the question.

    The client numbers the questions of a batch itself, so a number in the
    question text would show up twice on the screen.
    """
    return re.sub(r"^\s*\d+[.)]\s*", "", question).strip() or question.strip()


def _is_missing_column(error: Exception) -> bool:
    """Report whether the database lacks a column the query asked for."""
    if not isinstance(error, APIError):
        return False
    return getattr(error, "code", None) in _MISSING_COLUMN_CODES


def _slots_from_record(record: dict[str, Any]) -> BudgetSlots:
    """Read the stored slots, ignoring an unusable payload."""
    raw = record.get("budget_slots")
    if not isinstance(raw, dict) or not raw:
        return BudgetSlots()
    try:
        return BudgetSlots.model_validate(raw)
    except Exception:  # noqa: BLE001 - a broken payload must not break the chat
        return BudgetSlots()


def _message_options(row: dict[str, Any]) -> tuple[str, ...]:
    """Read the offered choices out of a stored question message.

    The options live in the tool result of the question tool, so they are
    restored from there instead of being stored a second time.
    """
    if row.get("tool_name") != QUESTION_TOOL:
        return ()
    result = row.get("tool_result")
    if not isinstance(result, dict):
        return ()
    options = result.get("options") or []
    if options:
        return tuple(str(option) for option in options)
    # A batch carries its choices inside the questions; the flat list is kept
    # for the older clients that expect a single group.
    labels: list[str] = []
    for raw in result.get("questions") or []:
        if not isinstance(raw, dict):
            continue
        for item in raw.get("options") or []:
            if isinstance(item, dict) and item.get("label"):
                labels.append(str(item["label"]))
    return tuple(labels)


def _message_questions(row: dict[str, Any]) -> tuple[ChatQuestion, ...]:
    """Read the offered questions out of a stored question message.

    A batch of questions lives in the tool result of the question tool, so
    it is restored from there. A message written before the batch existed
    carries a single question and is read the old way.
    """
    if row.get("tool_name") != QUESTION_TOOL:
        return ()
    result = row.get("tool_result")
    if not isinstance(result, dict):
        return ()
    questions: list[ChatQuestion] = []
    for raw in result.get("questions") or []:
        if not isinstance(raw, dict):
            continue
        options = tuple(
            ChatQuestionOption(
                label=str(item.get("label") or ""),
                amount=(
                    str(item["amount"]) if item.get("amount") is not None else None
                ),
                exclusive=bool(item.get("exclusive")),
                answer=str(item.get("answer") or item.get("label") or ""),
            )
            for item in (raw.get("options") or [])
            if isinstance(item, dict) and item.get("label")
        )
        if not options:
            continue
        questions.append(
            ChatQuestion(
                question=_strip_number(str(raw.get("question") or "")),
                options=options,
                multi_select=bool(raw.get("multi_select")),
            )
        )
    return tuple(questions)


class SupabaseChatRepository:
    """Conversation persistence scoped to the owner."""

    def __init__(self, client: Client, user_id: str) -> None:
        self.client = client
        self.user_id = user_id

    def session(self, session_id: int) -> ChatSession:
        """Return one conversation owned by the authenticated user."""
        try:
            result = (
                self.client.table("ai_chat_sessions")
                .select(_SESSION_COLUMNS)
                .eq("user_id", self.user_id)
                .eq("id", session_id)
                .execute()
            )
        except APIError as error:
            if not _is_missing_column(error):
                raise
            result = (
                self.client.table("ai_chat_sessions")
                .select(_LEGACY_SESSION_COLUMNS)
                .eq("user_id", self.user_id)
                .eq("id", session_id)
                .execute()
            )
        if not result.data:
            raise ChatError(404, "Cuộc trò chuyện không tồn tại.")
        record = result.data[0]
        return ChatSession(
            id=int(record["id"]),
            title=record.get("title") or "Cuộc trò chuyện tư vấn",
            slots=_slots_from_record(record),
            created_at=record.get("created_at"),
            updated_at=record.get("updated_at"),
        )

    def list_sessions(self, limit: int, offset: int) -> dict:
        """List the conversations owned by the authenticated user."""
        try:
            result = (
                self.client.table("ai_chat_sessions")
                .select(_SESSION_COLUMNS, count="exact")
                .eq("user_id", self.user_id)
                .order("updated_at", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
            )
        except APIError as error:
            if not _is_missing_column(error):
                raise
            result = (
                self.client.table("ai_chat_sessions")
                .select(_LEGACY_SESSION_COLUMNS, count="exact")
                .eq("user_id", self.user_id)
                .order("updated_at", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
            )
        items = [
            ChatSession(
                id=int(record["id"]),
                title=record.get("title") or "Cuộc trò chuyện tư vấn",
                slots=_slots_from_record(record),
                created_at=record.get("created_at"),
                updated_at=record.get("updated_at"),
            )
            for record in result.data
        ]
        return {
            "items": items,
            "total": result.count or 0,
            "limit": limit,
            "offset": offset,
        }

    def create_session(self, title: str) -> ChatSession:
        """Start a new conversation."""
        result = (
            self.client.table("ai_chat_sessions")
            .insert({"user_id": self.user_id, "title": title})
            .execute()
        )
        if not result.data:
            raise ChatError(503, "Không tạo được cuộc trò chuyện.")
        record = result.data[0]
        return ChatSession(
            id=int(record["id"]),
            title=record.get("title") or title,
            slots=BudgetSlots(),
            created_at=record.get("created_at"),
            updated_at=record.get("updated_at"),
        )

    def messages(self, session_id: int, limit: int) -> list[ChatMessage]:
        """Return the most recent messages of one conversation."""
        try:
            result = (
                self.client.table("ai_chat_messages")
                .select(_MESSAGE_COLUMNS)
                .eq("session_id", session_id)
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )
        except APIError as error:
            if not _is_missing_column(error):
                raise
            result = (
                self.client.table("ai_chat_messages")
                .select(_LEGACY_MESSAGE_COLUMNS)
                .eq("session_id", session_id)
                .order("created_at", desc=True)
                .limit(limit)
                .execute()
            )
        rows = list(reversed(result.data or []))
        return [
            ChatMessage(
                id=int(row["id"]),
                session_id=int(row["session_id"]),
                sender=row["sender"],
                content=row.get("content") or "",
                tool_name=row.get("tool_name"),
                tool_args=row.get("tool_args"),
                tool_result=row.get("tool_result"),
                created_at=row.get("created_at"),
                options=_message_options(row),
                questions=_message_questions(row),
            )
            for row in rows
        ]

    def append_message(
        self,
        session_id: int,
        sender: Sender,
        content: str,
        tool_name: str | None = None,
        tool_args: dict | None = None,
        tool_result: dict | None = None,
    ) -> ChatMessage:
        """Append one message, with its tool trace when there is one."""
        payload: dict[str, Any] = {
            "session_id": session_id,
            "sender": sender,
            "content": content,
        }
        if tool_name is not None:
            payload["tool_name"] = tool_name
        if tool_args is not None:
            payload["tool_args"] = tool_args
        if tool_result is not None:
            payload["tool_result"] = tool_result
        try:
            result = self.client.table("ai_chat_messages").insert(payload).execute()
        except APIError as error:
            if not _is_missing_column(error):
                raise
            # The tool trace arrives with migration 202611010002. Without it
            # the conversation still works, only the audit trail is lost.
            result = (
                self.client.table("ai_chat_messages")
                .insert(
                    {
                        "session_id": session_id,
                        "sender": sender,
                        "content": content,
                    }
                )
                .execute()
            )
        if not result.data:
            raise ChatError(503, "Không lưu được tin nhắn.")
        row = result.data[0]
        return ChatMessage(
            id=int(row["id"]),
            session_id=int(row["session_id"]),
            sender=row["sender"],
            content=row.get("content") or "",
            tool_name=row.get("tool_name"),
            tool_args=row.get("tool_args"),
            tool_result=row.get("tool_result"),
            created_at=row.get("created_at"),
            options=_message_options(row),
            questions=_message_questions(row),
        )

    def save_slots(self, session_id: int, slots: BudgetSlots) -> None:
        """Store the collected slots on the conversation."""
        payload = slots.to_payload()
        try:
            self.client.table("ai_chat_sessions").update(
                {
                    "budget_slots": payload,
                    "budget_slots_updated_at": datetime.now(UTC).isoformat(),
                }
            ).eq("user_id", self.user_id).eq("id", session_id).execute()
        except APIError as error:
            if not _is_missing_column(error):
                raise
            # The slot columns arrive with migration 202611010002. Without
            # them the slots are dropped, so the assistant asks again.
            logger.warning(
                "Chat slots are not stored: migration 202611010002 is missing"
            )
