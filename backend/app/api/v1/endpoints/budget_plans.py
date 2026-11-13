"""HTTP endpoints for the deterministic budget engine."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, ConfigDict, Field

from app.api.dependencies import UserDependency
from app.application.budget_plan import (
    BudgetPlanService,
    PurchaseImpactService,
    SetupDefaultsService,
    rebalance,
    validate_rebalance_payload,
)
from app.domain.budget_plan import (
    BudgetPlan,
    BudgetPlanCreateInput,
    DailyAllocation,
    PlanAllocation,
    PlanEvent,
    PlanTotals,
    PurchaseImpactRequest,
    PurchaseImpactResult,
    RebalanceResult,
    SetupDefaults,
)
from app.domain.transactions import TransactionError
from app.infrastructure.repositories.budget_plans import SupabaseBudgetPlanRepository
from app.infrastructure.repositories.plan_balance import SupabasePlanBalanceSource
from app.infrastructure.repositories.setup_defaults import (
    SupabaseSetupDefaultsSource,
)

router = APIRouter(prefix="/api/v1/budget-plans", tags=["Budget plans"])


def get_budget_plan_service(context: UserDependency) -> BudgetPlanService:
    """Build the plan service for the authenticated owner."""
    repository = SupabaseBudgetPlanRepository(context.client, context.user_id)
    spending = SupabasePlanBalanceSource(context.client, context.user_id)
    return BudgetPlanService(repository, spending_source=spending)


def get_setup_defaults_service(context: UserDependency) -> SetupDefaultsService:
    """Build the monthly setup prefill for the authenticated owner."""
    return SetupDefaultsService(
        SupabaseSetupDefaultsSource(context.client, context.user_id)
    )


def get_purchase_impact_service(context: UserDependency) -> PurchaseImpactService:
    """Build the purchase impact service for the authenticated owner."""
    return PurchaseImpactService(
        SupabaseBudgetPlanRepository(context.client, context.user_id),
        balance_source=SupabasePlanBalanceSource(context.client, context.user_id),
    )


PlanService = Annotated[BudgetPlanService, Depends(get_budget_plan_service)]
ImpactService = Annotated[PurchaseImpactService, Depends(get_purchase_impact_service)]
SetupService = Annotated[SetupDefaultsService, Depends(get_setup_defaults_service)]


class PlanResponse(BaseModel):
    """A budget plan with its computed allocation."""

    model_config = ConfigDict(extra="forbid")

    plan: BudgetPlan


class PlanListResponse(BaseModel):
    """A page of budget plans."""

    model_config = ConfigDict(extra="forbid")

    items: list[BudgetPlan]
    total: int
    limit: int
    offset: int


class AllocationListResponse(BaseModel):
    """The daily projection of a plan."""

    model_config = ConfigDict(extra="forbid")

    items: list[DailyAllocation]


class EventListResponse(BaseModel):
    """The audit trail of a plan."""

    model_config = ConfigDict(extra="forbid")

    items: list[PlanEvent]


class RebalanceBody(BaseModel):
    """The body of a confirmed rebalance."""

    model_config = ConfigDict(extra="forbid")

    expected_version: int = Field(ge=1)
    current_day: int = Field(ge=1)
    purchase_amount: str = Field(default="0", max_length=32)
    allocations: list[PlanAllocation] = Field(min_length=1)
    idempotency_key: str = Field(min_length=36, max_length=36)
    account_id: int | None = None
    category_id: int | None = None
    description: str | None = Field(default=None, max_length=2000)


@router.post("", response_model=PlanResponse, status_code=201)
def create_plan(data: BudgetPlanCreateInput, service: PlanService) -> PlanResponse:
    """Create a plan from validated inputs; no language model computes money."""
    return PlanResponse(plan=service.create(data))


@router.get("", response_model=PlanListResponse)
def list_plans(
    service: PlanService,
    active: Annotated[bool, Query()] = False,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> PlanListResponse:
    """List the plans owned by the authenticated user."""
    page = service.list_plans(active, limit, offset)
    return PlanListResponse(**page)


# The setup routes are declared before `/{plan_id}` so their fixed paths are
# not read as a plan id.
@router.post("/preview", response_model=PlanTotals)
def preview_plan(data: BudgetPlanCreateInput, service: PlanService) -> PlanTotals:
    """Compute a plan from the setup answers without saving it."""
    return service.preview(data)


@router.get("/setup-defaults", response_model=SetupDefaults)
def setup_defaults(
    service: SetupService,
    today: Annotated[date | None, Query()] = None,
) -> SetupDefaults:
    """Prefill the monthly setup from the owner's wallets, schedule and profile.

    The client sends its own day, since the server clock runs on UTC; a day
    further than one day from the server's is refused.
    """
    server_today = date.today()
    if today is None:
        today = server_today
    elif abs((today - server_today).days) > 1:
        raise TransactionError(422, "Ngày hiện tại không hợp lệ.")
    return service.load(today)


@router.get("/{plan_id}", response_model=PlanResponse)
def get_plan(plan_id: int, service: PlanService) -> PlanResponse:
    """Return one plan owned by the authenticated user."""
    return PlanResponse(plan=service.get(plan_id))


@router.get("/{plan_id}/allocations", response_model=AllocationListResponse)
def get_allocations(plan_id: int, service: PlanService) -> AllocationListResponse:
    """Return the daily projection of a plan."""
    return AllocationListResponse(items=service.allocations(plan_id))


@router.get("/{plan_id}/events", response_model=EventListResponse)
def get_events(plan_id: int, service: PlanService) -> EventListResponse:
    """Return the audit trail of a plan."""
    return EventListResponse(items=service.events(plan_id))


@router.post("/{plan_id}/rebalance", response_model=RebalanceResult)
def rebalance_plan(
    plan_id: int, body: RebalanceBody, context: UserDependency
) -> RebalanceResult:
    """Apply a confirmed rebalance in a single database transaction."""
    payload = body.model_dump(mode="json")
    payload["plan_id"] = plan_id
    request = validate_rebalance_payload(payload)
    repository = SupabaseBudgetPlanRepository(context.client, context.user_id)
    return rebalance(repository, request)


@router.post("/{plan_id}/purchase-impact", response_model=PurchaseImpactResult)
def purchase_impact(
    plan_id: int, data: PurchaseImpactRequest, service: ImpactService
) -> PurchaseImpactResult:
    """Classify a proposed purchase against the plan and survival floor."""
    request = data.model_copy(update={"plan_id": plan_id})
    return service.simulate(request)
