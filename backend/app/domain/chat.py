"""Domain contracts for the conversational assistant.

The assistant talks to the user and calls tools. It never computes money:
every figure it repeats comes from a deterministic tool result (ADR 0009).
This module holds the value objects, the slot rules and the ports that the
application layer needs, so the language model stays outside the domain.
"""

from collections.abc import Sequence
from decimal import Decimal
from typing import Literal, Protocol

from pydantic import BaseModel, ConfigDict, Field, model_validator

#: Slots the assistant must collect before it may build a plan.
REQUIRED_SLOTS: tuple[str, ...] = (
    "total_income",
    "duration_days",
    "savings_target",
    "fixed_expenses",
)

#: Slots the assistant may collect, but never has to.
OPTIONAL_SLOTS: tuple[str, ...] = (
    "survival_floor_override",
    "group_ratios",
)

#: Every slot name the assistant may store.
KNOWN_SLOTS: tuple[str, ...] = REQUIRED_SLOTS + OPTIONAL_SLOTS

ToolName = Literal[
    "create_budget_plan",
    "simulate_purchase_impact",
    "search_nearby_similar_places",
    "confirm_and_rebalance_budget",
]

Sender = Literal["user", "assistant", "system"]


class ChatError(Exception):
    """An assistant failure with an actionable status and message."""

    def __init__(self, status: int, message: str, *, code: str | None = None):
        super().__init__(message)
        self.status = status
        self.message = message
        self.code = code


class ChatUnavailable(ChatError):
    """The conversational provider is not configured or temporarily unreachable.

    It is a `ChatError` so the API answers with a 503 and an actionable
    Vietnamese message instead of an opaque 500. The code tells the client
    whether the assistant is missing its key or merely busy.
    """

    def __init__(
        self, message: str, *, code: str = "not_configured", status: int = 503
    ) -> None:
        super().__init__(status, message, code=code)


class BudgetSlots(BaseModel):
    """The plan inputs collected so far, stored server-side.

    Every field is optional: the assistant asks for the missing ones. The
    values are the raw user-provided numbers; the deterministic engine
    validates them when the plan is created.
    """

    model_config = ConfigDict(extra="forbid")

    total_income: Decimal | None = Field(
        default=None, ge=0, max_digits=15, decimal_places=2
    )
    duration_days: int | None = Field(default=None, ge=1, le=365)
    savings_target: Decimal | None = Field(
        default=None, ge=0, max_digits=15, decimal_places=2
    )
    fixed_expenses: Decimal | None = Field(
        default=None, ge=0, max_digits=15, decimal_places=2
    )
    survival_floor_override: Decimal | None = Field(
        default=None, ge=0, max_digits=15, decimal_places=2
    )
    group_ratios: dict[str, int] | None = None

    @model_validator(mode="after")
    def validate_ratios(self):
        if self.group_ratios is None:
            return self
        if set(self.group_ratios) != {"food", "transport", "lifestyle"}:
            raise ValueError("Group ratios must cover food, transport and lifestyle")
        if sum(self.group_ratios.values()) != 100:
            raise ValueError("Group ratios must add up to 100")
        return self

    @property
    def missing(self) -> tuple[str, ...]:
        """The required slots that are still missing."""
        return tuple(name for name in REQUIRED_SLOTS if getattr(self, name) is None)

    @property
    def complete(self) -> bool:
        """True when every required slot has a value."""
        return not self.missing

    def merge(self, other: "BudgetSlots") -> "BudgetSlots":
        """Overlay the newly collected values on top of the stored ones.

        A `None` in `other` never erases a value that was already collected:
        the assistant must not ask the same question twice.
        """
        updates = {
            name: value
            for name in KNOWN_SLOTS
            if (value := getattr(other, name, None)) is not None
        }
        return self.model_copy(update=updates)

    def to_payload(self) -> dict:
        """Drop the unset slots so the stored JSON stays small and clear."""
        return self.model_dump(exclude_none=True, mode="json")


class ChatSession(BaseModel):
    """A conversation between the user and the assistant."""

    model_config = ConfigDict(extra="forbid")

    id: int
    title: str = "Cuộc trò chuyện tư vấn"
    slots: BudgetSlots = Field(default_factory=BudgetSlots)
    created_at: str | None = None
    updated_at: str | None = None


class ChatMessage(BaseModel):
    """One message in a conversation."""

    model_config = ConfigDict(extra="forbid")

    id: int
    session_id: int
    sender: Sender
    content: str
    tool_name: str | None = None
    tool_args: dict | None = None
    tool_result: dict | None = None
    created_at: str | None = None


class ToolCall(BaseModel):
    """A tool invocation proposed by the language model.

    The arguments are unvalidated here. The registry validates them before
    any service runs, so a malformed call never reaches the database.
    """

    model_config = ConfigDict(extra="forbid")

    name: str
    arguments: dict = Field(default_factory=dict)


class ToolOutcome(BaseModel):
    """The result of one tool invocation."""

    model_config = ConfigDict(extra="forbid")

    name: str
    ok: bool
    data: dict = Field(default_factory=dict)
    arguments: dict = Field(default_factory=dict)
    error: str | None = None
    error_code: str | None = None


class PlaceSuggestion(BaseModel):
    """One nearby place, filtered by rating, price level and open state."""

    model_config = ConfigDict(extra="forbid")

    name: str
    rating: float | None = None
    price_level: int | None = None
    open_now: bool | None = None
    address: str | None = None
    google_maps_uri: str | None = None


class ChatTurn(BaseModel):
    """The outcome of one assistant turn."""

    model_config = ConfigDict(extra="forbid")

    session_id: int
    reply: str
    tool_calls: tuple[ToolOutcome, ...] = ()
    slots: BudgetSlots = Field(default_factory=BudgetSlots)
    created_at: str | None = None


class ChatRepository(Protocol):
    """Persistence port for conversations and their collected slots."""

    def session(self, session_id: int) -> ChatSession: ...

    def list_sessions(self, limit: int, offset: int) -> dict: ...

    def create_session(self, title: str) -> ChatSession: ...

    def messages(self, session_id: int, limit: int) -> list[ChatMessage]: ...

    def append_message(
        self,
        session_id: int,
        sender: Sender,
        content: str,
        tool_name: str | None = None,
        tool_args: dict | None = None,
        tool_result: dict | None = None,
    ) -> ChatMessage: ...

    def save_slots(self, session_id: int, slots: BudgetSlots) -> None: ...


class PlacesSearch(Protocol):
    """Finds nearby places similar to what the user asked about."""

    @property
    def available(self) -> bool:
        """False when no provider is configured."""
        ...

    async def search(
        self,
        *,
        query: str,
        latitude: float,
        longitude: float,
        radius_m: int,
        max_price_level: int,
        min_rating: float,
    ) -> Sequence[PlaceSuggestion]: ...


class LanguageModel(Protocol):
    """The conversational tier: it talks and it calls tools, nothing else."""

    async def complete(
        self,
        *,
        system_prompt: str,
        user_input: str,
        slots: BudgetSlots,
        tools: Sequence[dict],
        history: Sequence[ChatMessage],
    ) -> tuple[str, tuple[ToolCall, ...]]:
        """Return the reply text and the tool calls the model proposed."""
        ...
