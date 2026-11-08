"""Application services for the deterministic budget engine.

These services orchestrate the domain calculations and the persistence port.
They never compute money with a language model and never trust a client
supplied user id.
"""

from decimal import Decimal

from pydantic import ValidationError

from app.domain.budget_plan import (
    BudgetPlan,
    BudgetPlanCreateInput,
    BudgetPlanRepository,
    DailyAllocation,
    PlanTotals,
    PurchaseImpactRequest,
    PurchaseImpactResult,
    RebalanceRequest,
    RebalanceResult,
    RemainingBalanceSource,
    build_daily_allocations,
    compute_plan_totals,
    evaluate_purchase_impact,
    propose_rebalance,
)
from app.domain.transactions import TransactionError


def plan_totals(plan: BudgetPlan) -> PlanTotals:
    """Rebuild the deterministic totals of a stored plan.

    The stored daily amounts are the source of truth; the ratios are only
    recovered to rebuild the group split for a proposal.
    """
    from app.domain.budget_plan import GROUP_PILLARS, PLAN_GROUPS

    groups = tuple(
        plan.groups[0].__class__(
            group_key=group.group_key,
            pillar=GROUP_PILLARS[group.group_key],
            daily_amount=group.daily_amount,
            total_amount=group.daily_amount * plan.duration_days,
        )
        for group in plan.groups
        if group.group_key in PLAN_GROUPS
    )
    return PlanTotals(
        spendable_budget=plan.spendable_budget,
        daily_allowance=plan.daily_allowance,
        survival_floor=plan.survival_floor,
        groups=groups,
    )


class BudgetPlanService:
    """Create, read and rebalance budget plans."""

    def __init__(
        self,
        repository: BudgetPlanRepository,
        balance_source: RemainingBalanceSource | None = None,
    ) -> None:
        self.repository = repository
        self.balance_source = balance_source

    def create(self, data: BudgetPlanCreateInput) -> BudgetPlan:
        """Build the allocation from validated inputs and persist it."""
        try:
            totals = compute_plan_totals(
                total_income=data.total_income,
                fixed_expenses=data.fixed_expenses,
                savings_target=data.savings_target,
                duration_days=data.duration_days,
                group_ratios=data.group_ratios,
                survival_floor_override=data.survival_floor_override,
            )
        except ValueError as error:
            raise TransactionError(422, str(error)) from error
        allocations = build_daily_allocations(
            totals=totals,
            duration_days=data.duration_days,
            start_date=data.start_date,
        )
        plan = BudgetPlan(
            id=0,
            title=data.title,
            status="ACTIVE",
            total_income=data.total_income,
            duration_days=data.duration_days,
            savings_target=data.savings_target,
            fixed_expenses=data.fixed_expenses,
            start_date=data.start_date,
            spendable_budget=totals.spendable_budget,
            daily_allowance=totals.daily_allowance,
            survival_floor=totals.survival_floor,
            plan_version=1,
            config_version="budget-engine-v1",
            groups=totals.groups,
            idempotency_key=data.idempotency_key,
        )
        return self.repository.create(plan, allocations)

    def get(self, plan_id: int) -> BudgetPlan:
        """Return one plan owned by the authenticated user."""
        return self.repository.get(plan_id)

    def list_plans(self, active_only: bool, limit: int, offset: int) -> dict:
        """List plans owned by the authenticated user."""
        return self.repository.list_plans(active_only, limit, offset)

    def allocations(self, plan_id: int) -> list[DailyAllocation]:
        """Return the daily projection of a plan."""
        self.repository.get(plan_id)
        return self.repository.allocations(plan_id)

    def events(self, plan_id: int):
        """Return the audit trail of a plan."""
        self.repository.get(plan_id)
        return self.repository.events(plan_id)

    def remaining_budget(self, plan: BudgetPlan, current_day: int) -> Decimal:
        """Return the money still available in the plan on a given day."""
        if current_day < 1 or current_day > plan.duration_days:
            raise TransactionError(422, "Ngày không thuộc kế hoạch này.")
        remaining_days = plan.duration_days - current_day + 1
        return plan.spendable_budget * remaining_days / plan.duration_days

    def propose(self, plan_id: int, current_day: int, purchase_amount: Decimal):
        """Return the deterministic rebalance proposal for a purchase."""
        plan = self.repository.get(plan_id)
        capacity = self.repository.envelope_capacity(plan.start_date)
        totals = plan_totals(plan)
        try:
            return propose_rebalance(
                totals=totals,
                duration_days=plan.duration_days,
                current_day=current_day,
                purchase_amount=purchase_amount,
                remaining_budget=self.remaining_budget(plan, current_day),
                capacity=capacity,
            )
        except ValueError as error:
            raise TransactionError(422, str(error)) from error


class PurchaseImpactService:
    """Answer whether a proposed purchase still fits the plan."""

    def __init__(
        self,
        repository: BudgetPlanRepository,
        balance_source: RemainingBalanceSource | None = None,
    ) -> None:
        self.repository = repository
        self.balance_source = balance_source

    def simulate(self, request: PurchaseImpactRequest) -> PurchaseImpactResult:
        """Classify the purchase; never guess when history is missing."""
        plan = self.repository.get(request.plan_id)
        remaining_balance = None
        if self.balance_source is not None:
            remaining_balance = self.balance_source.remaining_balance(
                plan, request.current_day
            )
        try:
            return evaluate_purchase_impact(
                plan=plan,
                current_day=request.current_day,
                amount=request.amount,
                remaining_balance=remaining_balance,
            )
        except ValueError as error:
            raise TransactionError(422, str(error)) from error


def validate_rebalance_payload(payload: dict) -> RebalanceRequest:
    """Validate a rebalance payload before any write happens."""
    try:
        return RebalanceRequest.model_validate(payload)
    except ValidationError as error:
        raise TransactionError(422, "Invalid rebalance payload") from error


def rebalance(
    repository: BudgetPlanRepository, request: RebalanceRequest
) -> RebalanceResult:
    """Execute a confirmed rebalance through the single-transaction port."""
    try:
        return repository.rebalance(request)
    except TransactionError:
        raise
    except ValueError as error:
        raise TransactionError(422, str(error)) from error
