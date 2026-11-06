"""Tool contract for the conversational assistant.

Five tools are exposed to the language model. They are described to the model
as function declarations, and each one has a Pydantic argument model that is
validated before any service runs. A tool never computes money: it delegates
to the deterministic budget services (ADR 0009).

The registry enforces the rules of `docs/DYNAMIC_BUDGET_SPEC.md` section 10:

1. Arguments are validated before the handler runs; a failure writes nothing.
2. Plan ownership comes from the server-side user id, never from the model.
3. A tool never computes money.
4. At most one tool call per turn.
5. A writing tool carries an idempotency key.
6. A writing tool carries the expected plan version.
"""

from collections.abc import Awaitable, Callable, Sequence
from dataclasses import dataclass
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    ValidationError,
    field_validator,
    model_validator,
)

from app.domain.budget_plan import (
    GroupKey,
    PlanAllocation,
    RebalanceRequest,
)
from app.domain.chat import MAX_QUESTION_OPTIONS, ToolCall, ToolOutcome

#: The five tools the assistant may call.
TOOL_NAMES: tuple[str, ...] = (
    "create_budget_plan",
    "simulate_purchase_impact",
    "search_nearby_similar_places",
    "confirm_and_rebalance_budget",
    "ask_user_question",
)

#: Tools that write to the database. Only these need an idempotency key.
WRITING_TOOLS: frozenset[str] = frozenset(
    {"create_budget_plan", "confirm_and_rebalance_budget"}
)


class CreateBudgetPlanArgs(BaseModel):
    """Arguments for `create_budget_plan`."""

    model_config = ConfigDict(extra="forbid")

    total_income: Decimal = Field(ge=0, max_digits=15, decimal_places=2)
    duration_days: int = Field(ge=1, le=365)
    savings_target: Decimal = Field(
        default=Decimal("0"), ge=0, max_digits=15, decimal_places=2
    )
    fixed_expenses: Decimal = Field(
        default=Decimal("0"), ge=0, max_digits=15, decimal_places=2
    )
    survival_floor_override: Decimal | None = Field(
        default=None, ge=0, max_digits=15, decimal_places=2
    )
    idempotency_key: str | None = Field(default=None, min_length=36, max_length=36)


class SimulatePurchaseImpactArgs(BaseModel):
    """Arguments for `simulate_purchase_impact`."""

    model_config = ConfigDict(extra="forbid")

    plan_id: int = Field(gt=0)
    current_day: int = Field(ge=1)
    item_name: str = Field(min_length=1, max_length=200)
    price: Decimal = Field(gt=0, max_digits=15, decimal_places=2)
    group_key: GroupKey = "lifestyle"
    category: str | None = Field(default=None, max_length=120)


class SearchNearbySimilarPlacesArgs(BaseModel):
    """Arguments for `search_nearby_similar_places`."""

    model_config = ConfigDict(extra="forbid")

    query: str = Field(min_length=1, max_length=200)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    radius_m: int = Field(default=1500, ge=100, le=5000)
    max_price_level: int = Field(default=2, ge=0, le=4)
    min_rating: float = Field(default=4.2, ge=0, le=5)


class ConfirmRebalanceArgs(BaseModel):
    """Arguments for `confirm_and_rebalance_budget`."""

    model_config = ConfigDict(extra="forbid")

    plan_id: int = Field(gt=0)
    expected_version: int = Field(ge=1)
    current_day: int = Field(ge=1)
    purchase_amount: Decimal = Field(
        default=Decimal("0"), ge=0, max_digits=15, decimal_places=2
    )
    group_key: GroupKey = "lifestyle"
    description: str | None = Field(default=None, max_length=2000)
    idempotency_key: str | None = Field(default=None, min_length=36, max_length=36)


class AskUserQuestionArgs(BaseModel):
    """Arguments for `ask_user_question`.

    The assistant asks a multiple-choice question. The options are what the
    user sees as tappable chips, so they are short and mutually exclusive.
    """

    model_config = ConfigDict(extra="forbid")

    question: str = Field(min_length=1, max_length=500)
    options: list[str] = Field(min_length=2, max_length=MAX_QUESTION_OPTIONS)

    @field_validator("options")
    @classmethod
    def clean_options(cls, values: list[str]) -> list[str]:
        """Trim the options and drop the empty ones.

        An option the user cannot read is worse than one option fewer, so a
        blank entry is removed instead of being rendered as an empty chip.
        """
        cleaned = [value.strip()[:200] for value in values]
        return [value for value in cleaned if value]

    @model_validator(mode="after")
    def validate_options(self):
        """Refuse a question that would render without a single choice."""
        if len(self.options) < 2:
            raise ValueError("A question needs at least two options")
        return self


class ToolSpec(BaseModel):
    """The declarative description of one tool."""

    model_config = ConfigDict(extra="forbid", arbitrary_types_allowed=True)

    name: str
    description: str
    writes: bool
    input_model: type[BaseModel]


@dataclass(frozen=True)
class ToolHandler:
    """A callable bound to one tool."""

    spec: ToolSpec
    handler: Callable[..., Awaitable[dict]]

    async def __call__(self, arguments: dict) -> dict:
        return await self.handler(arguments)


class ToolRegistry:
    """Validates and runs the tools the assistant may call.

    The registry is the only path from the model to a service. Arguments are
    validated with the tool's own model, so a malformed call never reaches
    the budget engine, and the handler only ever receives validated data.
    """

    def __init__(self, handlers: Sequence[ToolHandler]) -> None:
        self._handlers = {handler.spec.name: handler for handler in handlers}
        missing = set(TOOL_NAMES) - set(self._handlers)
        if missing:
            raise ValueError(f"Missing tool handlers: {sorted(missing)}")

    @property
    def names(self) -> tuple[str, ...]:
        """The names of every registered tool."""
        return tuple(sorted(self._handlers))

    def description(self, name: str) -> str:
        """The description of one tool."""
        return self._handlers[name].spec.description

    def writes(self, name: str) -> bool:
        """True when the tool writes to the database."""
        return self._handlers[name].spec.writes

    def declarations(self) -> list[dict]:
        """The Gemini function declarations for the registered tools."""
        declarations: list[dict] = []
        for name in TOOL_NAMES:
            handler = self._handlers[name]
            schema = handler.spec.input_model.model_json_schema()
            declarations.append(
                {
                    "name": name,
                    "description": handler.spec.description,
                    "parameters": _clean_schema(schema),
                }
            )
        return declarations

    async def run(self, call: ToolCall) -> ToolOutcome:
        """Validate the arguments and run one tool.

        A validation failure, an ownership failure or a service error is
        returned as a structured outcome. Nothing is written when the
        arguments are invalid.
        """
        handler = self._handlers.get(call.name)
        if handler is None:
            return ToolOutcome(
                name=call.name,
                ok=False,
                error=f"Unknown tool: {call.name}",
                error_code="unknown_tool",
            )
        try:
            arguments = handler.spec.input_model.model_validate(call.arguments)
        except ValidationError as error:
            return ToolOutcome(
                name=call.name,
                ok=False,
                error=_validation_message(error),
                error_code="invalid_arguments",
            )
        try:
            data = await handler(arguments)
        except Exception as error:  # noqa: BLE001 - reported as a tool outcome
            return ToolOutcome(
                name=call.name,
                ok=False,
                arguments=tool_arguments(arguments),
                error=str(error),
                error_code=getattr(error, "code", None) or "tool_failed",
            )
        return ToolOutcome(
            name=call.name,
            ok=True,
            data=data,
            arguments=tool_arguments(arguments),
        )


#: JSON-schema keywords the Gemini function-calling API does not accept.
_UNSUPPORTED_KEYWORDS = frozenset(
    {
        "additionalProperties",
        "title",
        "$defs",
        "$ref",
        "exclusiveMinimum",
        "exclusiveMaximum",
        "pattern",
        "examples",
    }
)

#: The Gemini type of every JSON-schema type.
_GEMINI_TYPES = {
    "string": "STRING",
    "number": "NUMBER",
    "integer": "INTEGER",
    "boolean": "BOOLEAN",
    "array": "ARRAY",
    "object": "OBJECT",
    "null": "NULL",
}


def _clean_schema(schema: dict) -> dict:
    """Convert a Pydantic JSON schema into a Gemini function declaration.

    The Gemini API accepts a narrower dialect than JSON Schema: it has no
    `exclusiveMinimum`, no `pattern` and no `anyOf`. A schema with those
    keywords is rejected before the request leaves the process, so the
    assistant would answer nothing at all.
    """
    return _clean_node(schema)


def _clean_node(node: dict) -> dict:
    """Clean one schema node and everything below it."""
    if not isinstance(node, dict):
        return node

    variants = node.get("anyOf")
    if isinstance(variants, list):
        node = _flatten_variants(node, variants)

    cleaned: dict = {}
    for key, value in node.items():
        if key in _UNSUPPORTED_KEYWORDS:
            continue
        if key == "type":
            cleaned[key] = _GEMINI_TYPES.get(value, value)
            continue
        if key == "properties" and isinstance(value, dict):
            cleaned[key] = {
                name: _clean_node(definition) for name, definition in value.items()
            }
            continue
        if key == "items" and isinstance(value, dict):
            cleaned[key] = _clean_node(value)
            continue
        cleaned[key] = value

    if "exclusiveMinimum" in node:
        cleaned.setdefault("minimum", node["exclusiveMinimum"])
    if "exclusiveMaximum" in node:
        cleaned.setdefault("maximum", node["exclusiveMaximum"])
    return cleaned


def _flatten_variants(node: dict, variants: list) -> dict:
    """Turn an `anyOf` into a single schema the Gemini API accepts.

    A nullable field becomes one schema with `nullable: true`. A field that
    accepts a number or a numeric string keeps the number, because the model
    sends a number and the argument model parses both.
    """
    flattened = {key: value for key, value in node.items() if key != "anyOf"}
    candidates = [item for item in variants if isinstance(item, dict)]
    nullable = any(item.get("type") == "null" for item in candidates)
    concrete = [item for item in candidates if item.get("type") != "null"]

    chosen: dict = {}
    for item in concrete:
        if item.get("type") == "number":
            chosen = item
            break
    if not chosen and concrete:
        chosen = concrete[0]

    for key, value in chosen.items():
        flattened.setdefault(key, value)
    for key in list(flattened):
        if key in _UNSUPPORTED_KEYWORDS:
            flattened.pop(key)

    if nullable:
        flattened["nullable"] = True
    return flattened


def _validation_message(error: ValidationError) -> str:
    """Describe the first invalid argument in a way the model can act on."""
    first = error.errors()[0]
    location = ".".join(str(part) for part in first.get("loc", ()))
    message = first.get("msg", "invalid value")
    return f"{location}: {message}" if location else message


def allocation_payload(allocations: Sequence[PlanAllocation]) -> list[dict]:
    """Convert allocations into the JSON shape the database expects."""
    return [
        {
            "group_key": item.group_key,
            "pillar": item.pillar,
            "daily_amount": str(item.daily_amount),
        }
        for item in allocations
    ]


def rebalance_request(
    arguments: ConfirmRebalanceArgs,
    allocations: Sequence[PlanAllocation],
    idempotency_key: UUID,
) -> RebalanceRequest:
    """Build the rebalance request the service expects."""
    return RebalanceRequest(
        plan_id=arguments.plan_id,
        expected_version=arguments.expected_version,
        current_day=arguments.current_day,
        purchase_amount=arguments.purchase_amount,
        allocations=tuple(allocations),
        idempotency_key=idempotency_key,
        description=arguments.description,
    )


def tool_arguments(arguments: Any) -> dict:
    """Render validated arguments as plain JSON data for the audit trail."""
    return arguments.model_dump(mode="json")
