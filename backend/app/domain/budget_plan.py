"""Deterministic budget-plan domain for the four-pillar envelope model.

The engine never asks a language model for an amount. Every number in this
module is derived from validated inputs with fixed decimal arithmetic so the
same inputs always produce the same plan, rebalance proposal and impact level.

Vocabulary follows the shared glossary: a *budget plan* projects daily
allocations, while `public.budgets` stays the only source of truth about
envelope limits.
"""

from datetime import date
from decimal import ROUND_HALF_UP, Decimal
from typing import Literal, Protocol
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator

Pillar = Literal["needs", "wants", "culture", "unexpected"]
GroupKey = Literal["food", "transport", "lifestyle", "other"]
PlanStatus = Literal[
    "COLLECTING",
    "READY",
    "ACTIVE",
    "REBALANCED",
    "EXPIRED",
    "CANCELLED",
]
ImpactLevel = Literal[
    "SAFE",
    "WARNING_REBALANCE_NEEDED",
    "CRITICAL_DANGER",
    "INSUFFICIENT_DATA",
]

CONFIG_VERSION = "budget-engine-v1"

#: Default share of the spendable budget per planning group.
DEFAULT_GROUP_RATIOS: dict[str, int] = {
    "food": 60,
    "transport": 15,
    "lifestyle": 25,
}

#: Pillars the engine may reduce, in the order the engine reduces them.
CUT_ORDER: tuple[Pillar, ...] = ("wants", "culture", "unexpected")

#: Minimum consecutive daily balances required before a forecast is trusted.
MIN_BALANCE_POINTS = 8

_CENTS = Decimal("0.01")

#: Every planning group belongs to exactly one envelope pillar.
GROUP_PILLARS: dict[str, Pillar] = {
    "food": "needs",
    "transport": "needs",
    "lifestyle": "wants",
    "other": "unexpected",
}

#: Planning groups created for every new plan, in a stable order.
PLAN_GROUPS: tuple[str, ...] = ("food", "transport", "lifestyle")


def quantize_money(value: Decimal) -> Decimal:
    """Round a money amount to two decimals, half away from zero."""
    return value.quantize(_CENTS, rounding=ROUND_HALF_UP)


class RebalanceInfeasible(ValueError):
    """Raised when no valid allocation can absorb the requested purchase."""


class GroupRatios(BaseModel):
    """Percentage split of the spendable budget across planning groups."""

    model_config = ConfigDict(extra="forbid")

    food: int = Field(default=60, ge=0, le=100)
    transport: int = Field(default=15, ge=0, le=100)
    lifestyle: int = Field(default=25, ge=0, le=100)

    @model_validator(mode="after")
    def validate_total(self):
        if self.food + self.transport + self.lifestyle != 100:
            raise ValueError("Group ratios must add up to 100")
        return self


class BudgetPlanCreateInput(BaseModel):
    """Validated inputs required to build a plan."""

    model_config = ConfigDict(extra="forbid")

    title: str = Field(default="Kế hoạch chi tiêu", min_length=1, max_length=120)
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
    group_ratios: GroupRatios = Field(default_factory=GroupRatios)
    start_date: date = Field(default_factory=date.today)
    idempotency_key: UUID | None = None


class PlanGroup(BaseModel):
    """One planning group inside a plan."""

    model_config = ConfigDict(extra="forbid")

    group_key: GroupKey
    pillar: Pillar
    daily_amount: Decimal
    total_amount: Decimal


class PlanTotals(BaseModel):
    """Deterministic totals derived from validated plan inputs."""

    model_config = ConfigDict(extra="forbid")

    spendable_budget: Decimal
    daily_allowance: Decimal
    survival_floor: Decimal
    groups: tuple[PlanGroup, ...]


class BudgetPlan(BaseModel):
    """A persisted budget plan with its computed allocation."""

    model_config = ConfigDict(extra="forbid")

    id: int
    title: str
    status: PlanStatus
    total_income: Decimal
    duration_days: int
    savings_target: Decimal
    fixed_expenses: Decimal
    start_date: date
    spendable_budget: Decimal
    daily_allowance: Decimal
    survival_floor: Decimal
    plan_version: int
    config_version: str
    groups: tuple[PlanGroup, ...]
    created_at: str | None = None
    updated_at: str | None = None


class DailyAllocation(BaseModel):
    """One group allocation for one day of a plan."""

    model_config = ConfigDict(extra="forbid")

    day_index: int
    alloc_date: date
    group_key: GroupKey
    pillar: Pillar
    amount: Decimal
    actual_spent: Decimal = Decimal("0")


class PlanAllocation(BaseModel):
    """A proposed daily amount for one group, used by rebalance proposals."""

    model_config = ConfigDict(extra="forbid")

    group_key: GroupKey
    pillar: Pillar
    daily_amount: Decimal = Field(ge=0, max_digits=15, decimal_places=2)


class PlanEvent(BaseModel):
    """Audit record of a plan mutation."""

    model_config = ConfigDict(extra="forbid")

    id: int
    plan_id: int
    event_type: str
    proposal: dict = Field(default_factory=dict)
    accepted: dict = Field(default_factory=dict)
    before_state: dict | None = None
    after_state: dict | None = None
    created_at: str | None = None


class EnvelopeCapacity(BaseModel):
    """Configured limits for one pillar, read from `public.budgets`."""

    model_config = ConfigDict(extra="forbid")

    pillar: Pillar
    category_limit_total: Decimal = Decimal("0")
    pillar_envelope: Decimal | None = None
    total_budget: Decimal | None = None

    @property
    def funded(self) -> bool:
        """A pillar with category limits must keep a positive envelope."""
        return self.category_limit_total > 0


class PurchaseImpactRequest(BaseModel):
    """Inputs for the pre-purchase simulation."""

    model_config = ConfigDict(extra="forbid")

    plan_id: int
    current_day: int = Field(ge=1)
    amount: Decimal = Field(gt=0, max_digits=15, decimal_places=2)
    group_key: GroupKey = "lifestyle"
    category: str | None = Field(default=None, max_length=120)


class PurchaseImpactResult(BaseModel):
    """Deterministic verdict for a proposed purchase."""

    model_config = ConfigDict(extra="forbid")

    level: ImpactLevel
    plan_id: int
    daily_allowance_now: Decimal
    daily_allowance_after: Decimal | None = None
    survival_floor: Decimal
    remaining_days: int
    reason: str


class RebalanceRequest(BaseModel):
    """A confirmed rebalance request against a known plan version."""

    model_config = ConfigDict(extra="forbid")

    plan_id: int
    expected_version: int = Field(ge=1)
    current_day: int = Field(ge=1)
    purchase_amount: Decimal = Field(
        default=Decimal("0"), ge=0, max_digits=15, decimal_places=2
    )
    allocations: tuple[PlanAllocation, ...] = Field(min_length=1)
    idempotency_key: UUID
    account_id: int | None = None
    category_id: int | None = None
    description: str | None = Field(default=None, max_length=2000)


class RebalanceResult(BaseModel):
    """Outcome of a confirmed rebalance."""

    model_config = ConfigDict(extra="forbid")

    plan_id: int
    plan_version: int
    rebalanced: bool
    before: dict[str, Decimal]
    after: dict[str, Decimal]
    daily_allowance_before: Decimal
    daily_allowance_after: Decimal
    survival_floor: Decimal
    transaction_id: int | None = None
    warnings: tuple[str, ...] = ()


class RebalanceProposal(BaseModel):
    """A deterministic rebalance proposal for the remaining days of a plan."""

    model_config = ConfigDict(extra="forbid")

    allocations: tuple[PlanAllocation, ...]
    daily_allowance_before: Decimal
    daily_allowance_after: Decimal
    remaining_days: int
    warnings: tuple[str, ...] = ()


class BudgetPlanRepository(Protocol):
    """Persistence port for budget plans."""

    def create(
        self, plan: BudgetPlan, allocations: list[DailyAllocation]
    ) -> BudgetPlan: ...

    def get(self, plan_id: int) -> BudgetPlan: ...

    def list_plans(self, active_only: bool, limit: int, offset: int) -> dict: ...

    def allocations(self, plan_id: int) -> list[DailyAllocation]: ...

    def events(self, plan_id: int) -> list[PlanEvent]: ...

    def envelope_capacity(self, month: date) -> dict[str, EnvelopeCapacity]: ...

    def rebalance(self, request: RebalanceRequest) -> RebalanceResult: ...


class RemainingBalanceSource(Protocol):
    """Provides the money left on a given plan day, or `None` when unknown."""

    def remaining_balance(self, plan: BudgetPlan, day_index: int) -> Decimal | None: ...


def compute_plan_totals(
    *,
    total_income: Decimal,
    fixed_expenses: Decimal,
    savings_target: Decimal,
    duration_days: int,
    group_ratios: GroupRatios,
    survival_floor_override: Decimal | None = None,
) -> PlanTotals:
    """Derive the spendable budget, daily allowance and group split."""
    spendable = total_income - fixed_expenses - savings_target
    if spendable <= 0:
        raise ValueError(
            "Total income must exceed fixed expenses plus savings target"
        )
    daily_allowance = quantize_money(spendable / duration_days)
    survival_floor = (
        quantize_money(survival_floor_override)
        if survival_floor_override is not None
        else quantize_money(fixed_expenses / duration_days)
    )
    group_totals: dict[str, Decimal] = {}
    for group_key in ("food", "transport"):
        ratio = getattr(group_ratios, group_key)
        group_totals[group_key] = quantize_money(spendable * ratio / 100)
    # The remainder lands on the last group so the split always sums exactly.
    group_totals["lifestyle"] = quantize_money(
        spendable - group_totals["food"] - group_totals["transport"]
    )
    groups = tuple(
        PlanGroup(
            group_key=group_key,  # type: ignore[arg-type]
            pillar=GROUP_PILLARS[group_key],
            daily_amount=quantize_money(group_totals[group_key] / duration_days),
            total_amount=group_totals[group_key],
        )
        for group_key in PLAN_GROUPS
    )
    return PlanTotals(
        spendable_budget=quantize_money(spendable),
        daily_allowance=daily_allowance,
        survival_floor=survival_floor,
        groups=groups,
    )


def daily_group_amounts(total_amount: Decimal, duration_days: int) -> list[Decimal]:
    """Split a group total into per-day amounts that sum back to the total."""
    if duration_days < 1:
        raise ValueError("duration_days must be positive")
    base = quantize_money(total_amount / duration_days)
    amounts = [base] * (duration_days - 1)
    amounts.append(quantize_money(total_amount - base * (duration_days - 1)))
    return amounts


def build_daily_allocations(
    *,
    totals: PlanTotals,
    duration_days: int,
    start_date: date,
) -> list[DailyAllocation]:
    """Materialise every group for every day of the plan."""
    allocations: list[DailyAllocation] = []
    for group in totals.groups:
        amounts = daily_group_amounts(group.total_amount, duration_days)
        for index, amount in enumerate(amounts, start=1):
            allocations.append(
                DailyAllocation(
                    day_index=index,
                    alloc_date=date.fromordinal(start_date.toordinal() + index - 1),
                    group_key=group.group_key,
                    pillar=group.pillar,
                    amount=amount,
                )
            )
    return allocations


def _pillar_floors(
    capacity: dict[str, EnvelopeCapacity], duration_days: int
) -> dict[str, Decimal]:
    """Convert monthly envelope limits into daily floors per pillar.

    A pillar whose categories carry limits is funded: the engine may not cut it
    below those limits, so it may never be zeroed. Without a configured parent
    there is no implicit cap derived from the category limits themselves.
    """
    floors: dict[str, Decimal] = {}
    for pillar, entry in capacity.items():
        if entry.funded:
            floors[pillar] = quantize_money(entry.category_limit_total / duration_days)
        else:
            floors[pillar] = Decimal("0")
    return floors


def _group_floors(
    current: dict[str, Decimal], floors: dict[str, Decimal]
) -> dict[str, Decimal]:
    """Spread a pillar floor over its groups proportionally to current shares."""
    group_floors: dict[str, Decimal] = {}
    pillars: dict[str, list[str]] = {}
    for group_key in current:
        pillars.setdefault(GROUP_PILLARS[group_key], []).append(group_key)
    for pillar, members in pillars.items():
        floor = floors.get(pillar, Decimal("0"))
        member_total = sum((current[key] for key in members), Decimal("0"))
        if floor <= 0 or member_total <= 0:
            for key in members:
                group_floors[key] = Decimal("0")
            continue
        allocated = Decimal("0")
        for key in members[:-1]:
            share = quantize_money(floor * current[key] / member_total)
            group_floors[key] = share
            allocated += share
        group_floors[members[-1]] = quantize_money(floor - allocated)
    return group_floors


def propose_rebalance(
    *,
    totals: PlanTotals,
    duration_days: int,
    current_day: int,
    purchase_amount: Decimal,
    remaining_budget: Decimal,
    capacity: dict[str, EnvelopeCapacity],
) -> RebalanceProposal:
    """Propose new daily group amounts after a confirmed purchase.

    `remaining_budget` is the money still available in the plan, so the new
    daily allowance spreads the rest of the plan over the remaining days. The
    engine reduces cuttable pillars in a fixed order and never drops a funded
    pillar below the sum of its existing category limits. When the purchase
    cannot be absorbed the proposal is infeasible and nothing is written.
    """
    if current_day < 1 or current_day > duration_days:
        raise ValueError("current_day must fall inside the plan")
    remaining_days = duration_days - current_day + 1
    current = {group.group_key: group.daily_amount for group in totals.groups}
    current_total = sum(current.values(), Decimal("0"))
    available = remaining_budget - purchase_amount
    if available < 0:
        raise RebalanceInfeasible(
            "Purchase exceeds the remaining budget of the plan"
        )
    target_daily = quantize_money(available / remaining_days)

    floors = _pillar_floors(capacity, duration_days)
    group_floors = _group_floors(current, floors)
    proposed = dict(current)

    cut = quantize_money(current_total - target_daily)
    if cut > 0:
        # Reduce the pillars in a fixed order: wants, then culture, then
        # unexpected, and only then needs. Within a pillar the groups shrink
        # proportionally so the split keeps its shape.
        for pillar in (*CUT_ORDER, "needs"):
            if cut <= 0:
                break
            members = [key for key in proposed if GROUP_PILLARS[key] == pillar]
            if not members:
                continue
            pillar_total = sum((proposed[key] for key in members), Decimal("0"))
            reducible = quantize_money(
                sum(
                    (proposed[key] - group_floors[key] for key in members),
                    Decimal("0"),
                )
            )
            if reducible <= 0:
                continue
            take = min(cut, reducible)
            removed = Decimal("0")
            for key in members[:-1]:
                share = quantize_money(take * proposed[key] / pillar_total)
                share = min(share, quantize_money(proposed[key] - group_floors[key]))
                proposed[key] = quantize_money(proposed[key] - share)
                removed += share
            last = members[-1]
            share = quantize_money(take - removed)
            share = min(share, quantize_money(proposed[last] - group_floors[last]))
            proposed[last] = quantize_money(proposed[last] - share)
            removed += share
            cut = quantize_money(cut - removed)
    if cut > 0:
        raise RebalanceInfeasible(
            "Purchase cannot be absorbed without breaking an envelope limit"
        )

    warnings: list[str] = []
    for pillar in CUT_ORDER:
        members = [key for key in proposed if GROUP_PILLARS[key] == pillar]
        if not members:
            continue
        pillar_total = sum((proposed[key] for key in members), Decimal("0"))
        if pillar_total <= 0 and floors.get(pillar, Decimal("0")) > 0:
            raise RebalanceInfeasible(
                f"Pillar {pillar} still carries category limits and cannot be zeroed"
            )
        if pillar_total <= 0:
            warnings.append(f"{pillar} đã bị cắt về 0 để hấp thụ khoản mua")
    for pillar, floor in floors.items():
        if floor <= 0:
            continue
        members = [key for key in proposed if GROUP_PILLARS[key] == pillar]
        pillar_total = sum((proposed[key] for key in members), Decimal("0"))
        if pillar_total + Decimal("0.01") < floor:
            raise RebalanceInfeasible(
                f"Pillar {pillar} would fall below its category limits"
            )

    allocations = tuple(
        PlanAllocation(
            group_key=group.group_key,
            pillar=group.pillar,
            daily_amount=proposed[group.group_key],
        )
        for group in totals.groups
    )
    return RebalanceProposal(
        allocations=allocations,
        daily_allowance_before=quantize_money(current_total),
        daily_allowance_after=quantize_money(
            sum(proposed.values(), Decimal("0"))
        ),
        remaining_days=remaining_days,
        warnings=tuple(warnings),
    )


def evaluate_purchase_impact(
    *,
    plan: BudgetPlan,
    current_day: int,
    amount: Decimal,
    remaining_balance: Decimal | None,
) -> PurchaseImpactResult:
    """Classify a proposed purchase against the plan and the survival floor."""
    remaining_days = plan.duration_days - current_day + 1
    if remaining_days < 1:
        raise ValueError("current_day must fall inside the plan")
    if remaining_balance is None:
        return PurchaseImpactResult(
            level="INSUFFICIENT_DATA",
            plan_id=plan.id,
            daily_allowance_now=plan.daily_allowance,
            daily_allowance_after=None,
            survival_floor=plan.survival_floor,
            remaining_days=remaining_days,
            reason=(
                "Chưa đủ lịch sử số dư để dự báo, chưa thể kết luận khoản mua này."
            ),
        )
    daily_after = quantize_money((remaining_balance - amount) / remaining_days)
    if daily_after < plan.survival_floor:
        # Falling below the survival floor is the strongest signal, so it is
        # checked before the plain "still within the daily allowance" case.
        level: ImpactLevel = "CRITICAL_DANGER"
        reason = "Khoản mua khiến hạn mức ngày thấp hơn sàn sống tối thiểu."
    elif daily_after <= plan.daily_allowance:
        level = "SAFE"
        reason = "Khoản mua vẫn nằm trong hạn mức ngày của kế hoạch."
    else:
        level = "WARNING_REBALANCE_NEEDED"
        reason = "Khoản mua làm kế hoạch chặt hơn, nên cân nhắc điều chỉnh."
    return PurchaseImpactResult(
        level=level,
        plan_id=plan.id,
        daily_allowance_now=plan.daily_allowance,
        daily_allowance_after=daily_after,
        survival_floor=plan.survival_floor,
        remaining_days=remaining_days,
        reason=reason,
    )
