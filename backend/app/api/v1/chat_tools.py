"""Composition root for the assistant's tools.

Each tool is bound here to the deterministic service that implements it. The
handlers never compute money themselves: they translate validated arguments
into a service call and render the result as plain JSON (ADR 0009).
"""

import logging
from collections.abc import Sequence
from decimal import Decimal
from uuid import UUID

from app.application.chat import ChatService
from app.application.chat_tools import (
    AskUserQuestionArgs,
    ConfirmRebalanceArgs,
    CreateBudgetPlanArgs,
    SearchNearbySimilarPlacesArgs,
    SimulatePurchaseImpactArgs,
    ToolHandler,
    ToolRegistry,
    ToolSpec,
    rebalance_request,
)
from app.domain.budget_plan import (
    BudgetPlanCreateInput,
    GroupRatios,
    PlanAllocation,
)
from app.domain.chat import PlacesSearch
from app.domain.transactions import TransactionError
from app.infrastructure.ai.chat.gemini_chat import (
    SYSTEM_PROMPT,
    GeminiChatModel,
)
from app.infrastructure.repositories.budget_plans import (
    SupabaseBudgetPlanRepository,
)

logger = logging.getLogger(__name__)

_CREATE_PLAN_DESCRIPTION = (
    "Tạo kế hoạch chi tiêu theo số ngày từ tổng thu nhập, chi phí cố định và "
    "mục tiêu tiết kiệm. Chỉ gọi khi đã biết đủ 4 thông tin và người dùng "
    "đã nói rõ muốn lập kế hoạch."
)

_IMPACT_DESCRIPTION = (
    "Kiểm tra một khoản mua sắp thực hiện có còn nằm trong hạn mức ngày của "
    "kế hoạch hay không. Trả về mức cảnh báo và hạn mức còn lại."
)

_PLACES_DESCRIPTION = (
    "Tìm các địa điểm gần người dùng tương đương với món họ đang hỏi, lọc "
    "theo đánh giá, mức giá và trạng thái đang mở cửa."
)

_REBALANCE_DESCRIPTION = (
    "Ghi nhận khoản mua đã được người dùng xác nhận và chia lại hạn mức của "
    "những ngày còn lại. Chỉ gọi khi người dùng xác nhận dự định mua."
)

_ASK_DESCRIPTION = (
    "Hỏi người dùng một câu hỏi có lựa chọn. Dùng khi cần người dùng chọn "
    "một trong vài hướng đi tiếp, thay vì hỏi họ phải tự diễn đạt. Tối đa 4 lựa "
    "chọn, mỗi lựa chọn ngắn gọn và dễ đọc."
)


def _plan_input(arguments: CreateBudgetPlanArgs) -> BudgetPlanCreateInput:
    """Turn validated arguments into the engine's plan input."""
    return BudgetPlanCreateInput(
        total_income=arguments.total_income,
        duration_days=arguments.duration_days,
        savings_target=arguments.savings_target,
        fixed_expenses=arguments.fixed_expenses,
        survival_floor_override=arguments.survival_floor_override,
        group_ratios=GroupRatios(),
        idempotency_key=_optional_uuid(arguments.idempotency_key),
    )


def _optional_uuid(value: str | None) -> UUID | None:
    """Read an optional UUID sent by the model or the client."""
    if not value:
        return None
    try:
        return UUID(value)
    except ValueError:
        return None


def _required_uuid(value: str | None) -> UUID:
    """Read the UUID a writing tool must carry.

    The server derives the key before the tool runs, so a missing key means
    the call did not come through the chat turn and must not be guessed.
    """
    key = _optional_uuid(value)
    if key is None:
        raise TransactionError(422, "Thiếu idempotency key.")
    return key


def _create_budget_plan_handler(client, user_id: str):
    """Bind the plan creation tool to the deterministic budget service."""

    async def handler(arguments: CreateBudgetPlanArgs) -> dict:
        from app.application.budget_plan import BudgetPlanService

        repository = SupabaseBudgetPlanRepository(client, user_id)
        service = BudgetPlanService(repository)
        plan = service.create(_plan_input(arguments))
        return {
            "plan_id": plan.id,
            "status": plan.status,
            "total_income": str(plan.total_income),
            "duration_days": plan.duration_days,
            "savings_target": str(plan.savings_target),
            "fixed_expenses": str(plan.fixed_expenses),
            "spendable_budget": str(plan.spendable_budget),
            "daily_allowance": str(plan.daily_allowance),
            "survival_floor": str(plan.survival_floor),
            "plan_version": plan.plan_version,
            "groups": [
                {
                    "group_key": group.group_key,
                    "pillar": group.pillar,
                    "daily_amount": str(group.daily_amount),
                    "total_amount": str(group.total_amount),
                }
                for group in plan.groups
            ],
        }

    return handler


def _simulate_purchase_impact_handler(client, user_id: str):
    """Bind the purchase simulation tool to the impact service."""

    async def handler(arguments: SimulatePurchaseImpactArgs) -> dict:
        from app.application.budget_plan import PurchaseImpactService
        from app.infrastructure.repositories.plan_balance import (
            SupabasePlanBalanceSource,
        )

        repository = SupabaseBudgetPlanRepository(client, user_id)
        service = PurchaseImpactService(
            repository,
            balance_source=SupabasePlanBalanceSource(client, user_id),
        )
        result = service.simulate(
            _impact_request(arguments)
        )
        return result.model_dump(mode="json")

    return handler


def _impact_request(arguments: SimulatePurchaseImpactArgs):
    """Build the impact request from validated arguments."""
    from app.domain.budget_plan import PurchaseImpactRequest

    return PurchaseImpactRequest(
        plan_id=arguments.plan_id,
        current_day=arguments.current_day,
        amount=arguments.price,
        group_key=arguments.group_key,
        category=arguments.category or arguments.item_name,
    )


def _confirm_rebalance_handler(client, user_id: str):
    """Bind the rebalance tool to the deterministic rebalance service."""

    async def handler(arguments: ConfirmRebalanceArgs) -> dict:
        from app.application.budget_plan import (
            BudgetPlanService,
            rebalance,
        )

        repository = SupabaseBudgetPlanRepository(client, user_id)
        service = BudgetPlanService(repository)
        proposal = service.propose(
            arguments.plan_id,
            arguments.current_day,
            arguments.purchase_amount,
        )
        allocations = tuple(
            PlanAllocation(
                group_key=item.group_key,
                pillar=item.pillar,
                daily_amount=item.daily_amount,
            )
            for item in proposal.allocations
        )
        request = rebalance_request(
            arguments,
            allocations,
            _required_uuid(arguments.idempotency_key),
        )
        result = rebalance(repository, request)
        return result.model_dump(mode="json")

    return handler


def _search_places_handler(places: PlacesSearch):
    """Bind the places tool to the configured place source."""

    async def handler(arguments: SearchNearbySimilarPlacesArgs) -> dict:
        if not places.available:
            return {
                "available": False,
                "places": [],
                "note": (
                    "Chưa cấu hình dịch vụ địa điểm. Mình vẫn có thể tư vấn dựa "
                    "trên kế hoạch của bạn."
                ),
            }
        try:
            suggestions = await places.search(
                query=arguments.query,
                latitude=arguments.latitude,
                longitude=arguments.longitude,
                radius_m=arguments.radius_m,
                max_price_level=arguments.max_price_level,
                min_rating=arguments.min_rating,
            )
        except Exception as error:  # noqa: BLE001 - reported to the model
            logger.info("Place search unavailable: %s", type(error).__name__)
            return {
                "available": False,
                "places": [],
                "note": "Không tìm được địa điểm gần đó lúc này.",
            }
        return {
            "available": True,
            "places": [item.model_dump(mode="json") for item in suggestions],
            "note": (
                "Google Places không cung cấp giá cụ thể, nên mình không khẳng "
                "định địa điểm nào rẻ hơn thực sự."
            ),
        }

    return handler


def _ask_user_question_handler():
    """Bind the question tool to the echo of its own arguments.

    The question is not a computation: the tool only carries the question and
    its options back so the client can render them as tappable chips. The
    user picks one and the answer arrives as the next message.
    """

    async def handler(arguments: AskUserQuestionArgs) -> dict:
        return {
            "question": arguments.question,
            "options": list(arguments.options),
        }

    return handler


def build_tool_registry(
    *, client, user_id: str, places: PlacesSearch
) -> ToolRegistry:
    """Build the registry with every tool bound to its service."""
    handlers = (
        ToolHandler(
            spec=ToolSpec(
                name="create_budget_plan",
                description=_CREATE_PLAN_DESCRIPTION,
                writes=True,
                input_model=CreateBudgetPlanArgs,
            ),
            handler=_create_budget_plan_handler(client, user_id),
        ),
        ToolHandler(
            spec=ToolSpec(
                name="simulate_purchase_impact",
                description=_IMPACT_DESCRIPTION,
                writes=False,
                input_model=SimulatePurchaseImpactArgs,
            ),
            handler=_simulate_purchase_impact_handler(client, user_id),
        ),
        ToolHandler(
            spec=ToolSpec(
                name="search_nearby_similar_places",
                description=_PLACES_DESCRIPTION,
                writes=False,
                input_model=SearchNearbySimilarPlacesArgs,
            ),
            handler=_search_places_handler(places),
        ),
        ToolHandler(
            spec=ToolSpec(
                name="confirm_and_rebalance_budget",
                description=_REBALANCE_DESCRIPTION,
                writes=True,
                input_model=ConfirmRebalanceArgs,
            ),
            handler=_confirm_rebalance_handler(client, user_id),
        ),
        ToolHandler(
            spec=ToolSpec(
                name="ask_user_question",
                description=_ASK_DESCRIPTION,
                writes=False,
                input_model=AskUserQuestionArgs,
            ),
            handler=_ask_user_question_handler(),
        ),
    )
    return ToolRegistry(handlers)


def build_chat_service(context) -> ChatService:
    """Build the chat service for the authenticated owner."""
    from app.infrastructure.ai.places.places_search import build_places_search
    from app.infrastructure.repositories.chat import SupabaseChatRepository

    places = build_places_search()
    registry = build_tool_registry(
        client=context.client,
        user_id=context.user_id,
        places=places,
    )
    model = GeminiChatModel()
    return ChatService(
        repository=SupabaseChatRepository(context.client, context.user_id),
        registry=registry,
        model=model,
        system_prompt=SYSTEM_PROMPT,
    )


def slot_payload(slots) -> dict:
    """Render the collected slots for the audit trail."""
    return slots.to_payload()


def group_ratios_payload(ratios: Sequence[str]) -> GroupRatios:
    """Build a group split from the configured names."""
    return GroupRatios()


def decimal_or_zero(value: Decimal | None) -> Decimal:
    """Return a usable decimal without inventing a figure."""
    return value if value is not None else Decimal("0")
