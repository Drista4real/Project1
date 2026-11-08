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
    QuestionOptionArgs,
    SearchNearbySimilarPlacesArgs,
    SimulatePurchaseImpactArgs,
    SumAmountsArgs,
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
    "Hỏi người dùng một hoặc nhiều câu hỏi có lựa chọn. Gộp TẤT CẢ các câu "
    "hỏi còn thiếu vào MỘT lần gọi này (tối đa 5 câu). Dùng khi cần người dùng "
    "chọn một trong vài hướng đi tiếp, thay vì hỏi họ phải tự diễn đạt. Mỗi câu "
    "tối đa 5 lựa chọn, mỗi lựa chọn ngắn gọn và dễ đọc. Đặt multi_select=true "
    "khi người dùng được chọn nhiều; đặt exclusive=true cho đáp án loại trừ như "
    "'không có'. Với câu hỏi về số tiền, dùng ratio và base_amount thay vì tự "
    "tính ra con số. Không tự thêm lựa chọn 'Khác': người dùng luôn có ô nhập "
    "tự do."
)

_SUM_DESCRIPTION = (
    "Cộng tổng các khoản tiền người dùng đã chọn. Dùng khi cần tổng chi phí "
    "cố định hoặc tổng một nhóm khoản chi. Không tự cộng trong đầu."
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


def _option_amount(option: QuestionOptionArgs) -> str | None:
    """Compute the figure behind a ratio option.

    The model proposes a ratio of a figure the user already gave; the
    multiplication happens here, so the number on the chip is computed
    deterministically and never typed by the model (ADR 0009).
    """
    if option.ratio is None or option.base_amount is None:
        return None
    amount = (option.base_amount * Decimal(str(option.ratio))).quantize(
        Decimal("0.01")
    )
    return str(amount)


def _ask_user_question_handler():
    """Bind the question tool to the echo of its own arguments.

    The question is not a computation: the tool only carries the questions
    and their options back so the client can render them as tappable chips.
    The user picks one and the answer arrives as the next message.
    """

    async def handler(arguments: AskUserQuestionArgs) -> dict:
        questions = []
        for question in arguments.questions:
            options = []
            for option in question.options:
                amount = _option_amount(option)
                options.append(
                    {
                        "label": option.label,
                        "amount": amount,
                        "exclusive": option.exclusive,
                        # The answer is what the client sends back when the
                        # user picks this option. A ratio option answers
                        # with the computed figure, not with the ratio.
                        "answer": amount if amount is not None else option.label,
                    }
                )
            questions.append(
                {
                    "question": question.question,
                    "multi_select": question.multi_select,
                    "options": options,
                }
            )
        return {"questions": questions}

    return handler


def _sum_amounts_handler():
    """Bind the addition tool to a plain sum of the picked amounts.

    The model adds up the amounts the user picked, never in its head: the
    sum is the deterministic answer the model then reads (ADR 0009).
    """

    async def handler(arguments: SumAmountsArgs) -> dict:
        total = sum(arguments.amounts, Decimal("0")).quantize(Decimal("0.01"))
        return {
            "amounts": [str(amount) for amount in arguments.amounts],
            "total": str(total),
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
        ToolHandler(
            spec=ToolSpec(
                name="sum_amounts",
                description=_SUM_DESCRIPTION,
                writes=False,
                input_model=SumAmountsArgs,
            ),
            handler=_sum_amounts_handler(),
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
