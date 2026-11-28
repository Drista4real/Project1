"""Application service for the conversational assistant.

One turn of the conversation: load the stored slots, ask the model for a
reply, run at most one tool through the registry, feed the tool result back,
and record everything on the server.

The service never computes money. It delegates to the deterministic budget
services through the tool registry (ADR 0009) and it keeps the collected slots
on the server so an interrupted session resumes without re-asking (ADR 0010).
"""

import logging
import re
import uuid
from collections.abc import Sequence
from decimal import Decimal, InvalidOperation

from app.application.chat_tools import ToolRegistry
from app.domain.budget_plan import BudgetPlanCreateInput, GroupRatios
from app.domain.chat import (
    BudgetSlots,
    ChatError,
    ChatMessage,
    ChatQuestion,
    ChatQuestionOption,
    ChatRepository,
    ChatSession,
    ChatTurn,
    LanguageModel,
    PlaceSuggestion,
    ToolCall,
    ToolOutcome,
)
from app.domain.transactions import TransactionError

logger = logging.getLogger(__name__)


def _outcome_payload(outcome: ToolOutcome) -> dict:
    """Render a tool outcome for the audit trail.

    The recorded result keeps what actually ran: the data on success and the
    error on failure. The model's narration is never part of it.
    """
    if outcome.ok:
        return dict(outcome.data or {})
    return {
        "ok": False,
        "error": outcome.error,
        "error_code": outcome.error_code,
    }

#: How many past messages are replayed to the model.
HISTORY_LIMIT = 12

#: The model proposes at most one tool call per turn.
MAX_TOOL_CALLS = 1

#: Patterns that indicate an instruction embedded in user supplied data.
INJECTION_PATTERNS: tuple[str, ...] = (
    "ignore previous",
    "ignore all previous",
    "disregard the system",
    "you are now",
    "bo qua moi chi dan",
    "bo qua cac quy tac",
    "bo qua lenh",
    "system prompt",
    "treat this as an instruction",
    "coi nhu lenh",
)

#: Vietnamese letters with their tone-marked forms, used to compare plain text.
_DIACRITICS = str.maketrans(
    {
        "à": "a", "á": "a", "ả": "a", "ã": "a", "ạ": "a",
        "ằ": "a", "ắ": "a", "ẳ": "a", "ẵ": "a", "ặ": "a",
        "ầ": "a", "ấ": "a", "ẩ": "a", "ẫ": "a", "ậ": "a",
        "è": "e", "é": "e", "ẻ": "e", "ẽ": "e", "ẹ": "e",
        "ề": "e", "ế": "e", "ể": "e", "ễ": "e", "ệ": "e",
        "ì": "i", "í": "i", "ỉ": "i", "ĩ": "i", "ị": "i",
        "ò": "o", "ó": "o", "ỏ": "o", "õ": "o", "ọ": "o",
        "ồ": "o", "ố": "o", "ổ": "o", "ỗ": "o", "ộ": "o",
        "ờ": "o", "ớ": "o", "ở": "o", "ỡ": "o", "ợ": "o",
        "ù": "u", "ú": "u", "ủ": "u", "ũ": "u", "ụ": "u",
        "ừ": "u", "ứ": "u", "ử": "u", "ữ": "u", "ự": "u",
        "ỳ": "y", "ý": "y", "ỷ": "y", "ỹ": "y", "ỵ": "y",
        "đ": "d",
    }
)


def strip_vietnamese_diacritics(text: str) -> str:
    """Remove the Vietnamese tone marks so a plain comparison works."""
    return text.lower().translate(_DIACRITICS)


def looks_like_injection(text: str) -> bool:
    """Report whether the text tries to issue instructions to the assistant.

    The comparison ignores Vietnamese tone marks, so a message does not have to
    keep its accents to be detected. The pattern is a warning, not a block: the
    assistant still answers, but the turn is logged and the extracted data is
    never trusted as an instruction.
    """
    lowered = strip_vietnamese_diacritics(text)
    return any(pattern in lowered for pattern in INJECTION_PATTERNS)


#: The tool the assistant uses to ask a multiple-choice question.
QUESTION_TOOL = "ask_user_question"


def _strip_number(question: str) -> str:
    """Remove a number the model put in front of the question.

    The client numbers the questions of a batch itself, and the model reads
    the questions back by that number. A number in the question text would
    show up twice on the screen.
    """
    return re.sub(r"^\s*\d+[.)]\s*", "", question).strip() or question.strip()


def _question_questions(outcomes: tuple[ToolOutcome, ...]) -> tuple[ChatQuestion, ...]:
    """Read the offered questions out of the question tool's result.

    Only a successful question carries questions: a failed call is an error
    the user must be told about, not a set of choices to tap.
    """
    for outcome in outcomes:
        if outcome.name != QUESTION_TOOL or not outcome.ok:
            continue
        data = outcome.data or {}
        raw_questions = data.get("questions") or []
        questions: list[ChatQuestion] = []
        for raw in raw_questions:
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
    return ()


def _question_options(outcomes: tuple[ToolOutcome, ...]) -> tuple[str, ...]:
    """Read the flat list of labels out of the question tool's result.

    The client renders the questions as separate chip groups, so the flat list
    is only kept for the older clients that expect a single group.
    """
    labels: list[str] = []
    for question in _question_questions(outcomes):
        labels.extend(option.label for option in question.options)
    return tuple(labels)


#: The introduction of a batch of questions.
BATCH_INTRO = "Mình cần bạn trả lời mấy câu sau:"


def _batch_text(questions: tuple[ChatQuestion, ...]) -> str:
    """Render the introduction of a batch.

    The questions themselves are rendered by the client as the caption of
    each group of chips. The numbered list the model reads back lives in the
    tool trace, so it does not have to be repeated in the reply.
    """
    return BATCH_INTRO


class ChatService:
    """Run one conversation turn and persist the result."""

    def __init__(
        self,
        *,
        repository: ChatRepository,
        registry: ToolRegistry,
        model: LanguageModel,
        system_prompt: str,
    ) -> None:
        self.repository = repository
        self.registry = registry
        self.model = model
        self.system_prompt = system_prompt

    @property
    def assistant_available(self) -> bool:
        """False when the conversational provider is not configured."""
        return not getattr(self.model, "is_mock", False)

    def session(self, session_id: int) -> ChatSession:
        """Return one conversation owned by the authenticated user."""
        return self.repository.session(session_id)

    def list_sessions(self, limit: int, offset: int) -> dict:
        """List the conversations owned by the authenticated user."""
        return self.repository.list_sessions(limit, offset)

    def create_session(self, title: str) -> ChatSession:
        """Start a new conversation."""
        return self.repository.create_session(title)

    def messages(self, session_id: int, limit: int = 50) -> list[ChatMessage]:
        """Return the messages of one conversation."""
        self.repository.session(session_id)
        return self.repository.messages(session_id, limit)

    async def run_turn(
        self, *, session_id: int, user_input: str
    ) -> ChatTurn:
        """Handle one user message and return the assistant's answer."""
        message = user_input.strip()
        if not message:
            raise ChatError(422, "Nội dung tin nhắn không được để trống.")
        session = self.repository.session(session_id)
        slots = session.slots
        history = self.repository.messages(session_id, HISTORY_LIMIT)
        if looks_like_injection(message):
            logger.warning(
                "Chat turn contained instruction-like text in the user data region"
            )

        user_message = self.repository.append_message(session_id, "user", message)

        collected, reply, outcomes = await self._converse(
            slots=slots,
            history=history,
            message=message,
            turn_key=str(user_message.id),
        )

        slots = slots.merge(collected)
        options = _question_options(outcomes)
        questions = _question_questions(outcomes)
        self.repository.save_slots(session_id, slots)
        self.repository.append_message(
            session_id,
            "assistant",
            reply,
            tool_name=outcomes[0].name if outcomes else None,
            tool_args=outcomes[0].arguments if outcomes else None,
            tool_result=_outcome_payload(outcomes[0]) if outcomes else None,
        )
        return ChatTurn(
            session_id=session_id,
            reply=reply,
            tool_calls=tuple(outcomes),
            slots=slots,
            options=options,
            questions=questions,
        )

    async def _converse(
        self,
        *,
        slots: BudgetSlots,
        history: Sequence[ChatMessage],
        message: str,
        turn_key: str,
    ) -> tuple[BudgetSlots, str, tuple[ToolOutcome, ...]]:
        """Ask the model, run at most one tool, and ask the model to explain."""
        declarations = self.registry.declarations()
        reply, calls = await self.model.complete(
            system_prompt=self.system_prompt,
            user_input=message,
            slots=slots,
            tools=declarations,
            history=history,
        )
        if not calls:
            return BudgetSlots(), reply, ()

        call = calls[0]
        if len(calls) > 1:
            logger.info(
                "Model proposed %d tool calls; only the first one runs", len(calls)
            )
        call = self._with_idempotency_key(call, turn_key)
        outcome = await self.registry.run(call)
        collected = await self._collect_slots(call, outcome)
        if not outcome.ok:
            return collected, self._explain_failure(outcome), (outcome,)
        if call.name == QUESTION_TOOL:
            # The questions themselves are the answer. Asking the model to
            # narrate them would only add words around the choices the user
            # must tap.
            return collected, self._question_text(outcome), (outcome,)

        explanation = await self._explain_result(outcome)
        return collected, explanation, (outcome,)

    def _with_idempotency_key(self, call: ToolCall, turn_key: str) -> ToolCall:
        """Give a writing tool a stable idempotency key.

        The model never invents a key: it cannot count retries, and a key it
        repeats would silently replay an old write. The server derives one
        from the turn instead, so the same turn always produces the same key
        and a retry of that turn cannot write twice.
        """
        if not self.registry.writes(call.name):
            return call
        arguments = dict(call.arguments)
        if arguments.get("idempotency_key"):
            return call
        arguments["idempotency_key"] = str(
            uuid.uuid5(
                uuid.NAMESPACE_URL,
                f"kakeibo:chat:{call.name}:{turn_key}",
            )
        )
        return ToolCall(name=call.name, arguments=arguments)

    def _question_text(self, outcome: ToolOutcome) -> str:
        """Return the questions the assistant asked.

        A batch is rendered as a numbered list so the user can answer every
        question in one message and the model can map each answer back to
        the question it asked.
        """
        questions = _question_questions((outcome,))
        if questions:
            return _batch_text(questions)
        data = outcome.data or {}
        question = str(data.get("question") or "").strip()
        return question or "Bạn muốn mình giúp gì tiếp theo?"

    async def _explain_result(self, outcome: ToolOutcome) -> str:
        """Let the model describe the real tool result to the user."""
        from app.infrastructure.ai.chat.gemini_chat import tool_result_text

        try:
            reply, _ = await self.model.complete(
                system_prompt=self.system_prompt,
                user_input=(
                    "Kết quả công cụ vừa chạy:\n"
                    f"{tool_result_text(outcome)}\n\n"
                    "Hãy diễn giải kết quả này cho người dùng. "
                    "Chỉ dùng con số có trong kết quả."
                ),
                slots=BudgetSlots(),
                tools=(),
                history=(),
            )
        except Exception:  # noqa: BLE001 - keep the raw result as the answer
            logger.warning("Could not explain the tool result; returning it raw")
            return tool_result_text(outcome)
        return reply or tool_result_text(outcome)

    def _explain_failure(self, outcome: ToolOutcome) -> str:
        """Explain a failed tool call without inventing a result."""
        if outcome.error_code == "invalid_arguments" and outcome.name == QUESTION_TOOL:
            # The raw validation message names the Pydantic field and the
            # limit, which means nothing to the user. They only need to know
            # that the questions did not come through and that they can try
            # again.
            return (
                "Mình chưa gửi được câu hỏi lên. Bạn thử nói lại giúp mình nhé."
            )
        message = outcome.error or "Công cụ không thực hiện được."
        return f"{message}\n\nBạn có thể kiểm tra lại thông tin và thử lại nhé."
    async def _collect_slots(
        self, call: ToolCall, outcome: ToolOutcome
    ) -> BudgetSlots:
        """Store the plan inputs a successful plan creation revealed."""
        if call.name != "create_budget_plan" or not outcome.ok:
            return BudgetSlots()
        data = outcome.data or {}
        try:
            return BudgetSlots(
                total_income=Decimal(str(data.get("total_income", "0"))),
                duration_days=int(data.get("duration_days", 0)) or None,
                savings_target=Decimal(str(data.get("savings_target", "0"))),
                fixed_expenses=Decimal(str(data.get("fixed_expenses", "0"))),
            )
        except (InvalidOperation, TypeError, ValueError):
            logger.warning("Tool result did not carry usable plan inputs")
            return BudgetSlots()


def build_plan_input(slots: BudgetSlots) -> BudgetPlanCreateInput:
    """Turn the collected slots into a validated plan input.

    The engine still validates the arithmetic; this only refuses to build an
    input from slots that were never collected.
    """
    if not slots.complete:
        missing = ", ".join(slots.missing)
        raise TransactionError(422, f"Thiếu thông tin: {missing}")
    ratios = None
    if slots.group_ratios:
        ratios = GroupRatios(**slots.group_ratios)
    return BudgetPlanCreateInput(
        total_income=slots.total_income or Decimal("0"),
        duration_days=slots.duration_days or 0,
        savings_target=slots.savings_target or Decimal("0"),
        fixed_expenses=slots.fixed_expenses or Decimal("0"),
        survival_floor_override=slots.survival_floor_override,
        group_ratios=ratios or GroupRatios(),
    )


def place_suggestions_payload(
    suggestions: Sequence[PlaceSuggestion],
) -> list[dict]:
    """Render place suggestions as plain JSON for the audit trail."""
    return [item.model_dump(mode="json") for item in suggestions]
