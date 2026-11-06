"""Supabase persistence for budget plans and the rebalance RPC."""

from datetime import date
from decimal import Decimal
from typing import Any
from uuid import UUID

from postgrest.exceptions import APIError
from supabase import Client

from app.domain.budget_plan import (
    BudgetPlan,
    DailyAllocation,
    EnvelopeCapacity,
    PlanAllocation,
    PlanEvent,
    PlanGroup,
    RebalanceRequest,
    RebalanceResult,
)
from app.domain.transactions import TransactionError

_PILLARS = ("needs", "wants", "culture", "unexpected")


def _decimal(value: Any) -> Decimal:
    """Read a numeric column without losing cent precision."""
    if value is None:
        return Decimal("0")
    return Decimal(str(value))


def _month_start(value: date) -> date:
    return value.replace(day=1)


class SupabaseBudgetPlanRepository:
    """All budget plan reads and writes stay scoped to the owner."""

    def __init__(self, client: Client, user_id: str) -> None:
        self.client = client
        self.user_id = user_id

    # -- plans ---------------------------------------------------------------

    def create(
        self, plan: BudgetPlan, allocations: list[DailyAllocation]
    ) -> BudgetPlan:
        """Persist a plan with its daily projection in one round trip.

        The plan carries an optional idempotency key. A repeated request with
        the same key returns the plan that was already stored instead of
        writing a second one, so a retried call never duplicates a plan.
        """
        if plan.idempotency_key is not None:
            existing = self._find_by_idempotency_key(plan.idempotency_key)
            if existing is not None:
                return existing
        payload = {
            "user_id": self.user_id,
            "title": plan.title,
            "status": plan.status,
            "total_income": str(plan.total_income),
            "duration_days": plan.duration_days,
            "savings_target": str(plan.savings_target),
            "fixed_expenses": str(plan.fixed_expenses),
            "start_date": plan.start_date.isoformat(),
            "spendable_budget": str(plan.spendable_budget),
            "daily_allowance": str(plan.daily_allowance),
            "survival_floor": str(plan.survival_floor),
            "plan_version": plan.plan_version,
            "config_version": plan.config_version,
            "idempotency_key": (
                str(plan.idempotency_key)
                if plan.idempotency_key is not None
                else None
            ),
        }
        try:
            result = self.client.table("budget_plans").insert(payload).execute()
        except APIError as error:
            if error.code == "23505" and plan.idempotency_key is not None:
                existing = self._find_by_idempotency_key(plan.idempotency_key)
                if existing is not None:
                    return existing
            raise _rpc_error(error) from error
        if not result.data:
            raise TransactionError(409, "Unable to create budget plan")
        record = result.data[0]
        rows = [
            {
                "plan_id": record["id"],
                "day_index": item.day_index,
                "alloc_date": item.alloc_date.isoformat(),
                "group_key": item.group_key,
                "pillar": item.pillar,
                "amount": str(item.amount),
                "actual_spent": str(item.actual_spent),
            }
            for item in allocations
        ]
        if rows:
            self.client.table("daily_allocations").insert(rows).execute()
        return self._to_plan(record, plan.groups)

    def get(self, plan_id: int) -> BudgetPlan:
        """Return one plan owned by the authenticated user."""
        result = (
            self.client.table("budget_plans")
            .select("*")
            .eq("user_id", self.user_id)
            .eq("id", plan_id)
            .execute()
        )
        if not result.data:
            raise TransactionError(404, "Budget plan not found")
        record = result.data[0]
        return self._to_plan(record, self._groups_from_allocations(plan_id))

    def list_plans(self, active_only: bool, limit: int, offset: int) -> dict:
        """List plans owned by the authenticated user."""
        query = self.client.table("budget_plans").select("*", count="exact")
        query = query.eq("user_id", self.user_id)
        if active_only:
            query = query.in_("status", ["ACTIVE", "REBALANCED"])
        result = (
            query.order("id", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        items = [self._to_plan(record, ()) for record in result.data]
        return {
            "items": items,
            "total": result.count or 0,
            "limit": limit,
            "offset": offset,
        }

    def allocations(self, plan_id: int) -> list[DailyAllocation]:
        """Return the daily projection of a plan."""
        result = (
            self.client.table("daily_allocations")
            .select("*")
            .eq("plan_id", plan_id)
            .order("day_index")
            .order("group_key")
            .execute()
        )
        return [
            DailyAllocation(
                day_index=row["day_index"],
                alloc_date=date.fromisoformat(row["alloc_date"]),
                group_key=row["group_key"],
                pillar=row["pillar"],
                amount=_decimal(row["amount"]),
                actual_spent=_decimal(row["actual_spent"]),
            )
            for row in result.data
        ]

    def events(self, plan_id: int) -> list[PlanEvent]:
        """Return the audit trail of a plan."""
        result = (
            self.client.table("budget_plan_events")
            .select("*")
            .eq("plan_id", plan_id)
            .eq("user_id", self.user_id)
            .order("id")
            .execute()
        )
        return [
            PlanEvent(
                id=row["id"],
                plan_id=row["plan_id"],
                event_type=row["event_type"],
                proposal=row.get("proposal") or {},
                accepted=row.get("accepted") or {},
                before_state=row.get("before_state"),
                after_state=row.get("after_state"),
                created_at=row.get("created_at"),
            )
            for row in result.data
        ]

    def envelope_capacity(self, month: date) -> dict[str, EnvelopeCapacity]:
        """Read the configured envelope limits that constrain a plan."""
        month_start = _month_start(month)
        result = (
            self.client.table("budgets")
            .select("id, category_id, pillar, limit_amount, month_year")
            .eq("user_id", self.user_id)
            .eq("month_year", month_start.isoformat())
            .execute()
        )
        capacity = {
            pillar: EnvelopeCapacity(pillar=pillar) for pillar in _PILLARS
        }
        total_budget: Decimal | None = None
        category_totals: dict[str, Decimal] = {}
        category_pillars: dict[int, str | None] = {}
        for row in result.data:
            if row["category_id"] is None and row["pillar"] is None:
                total_budget = (total_budget or Decimal("0")) + _decimal(
                    row["limit_amount"]
                )
            elif row["category_id"] is None and row["pillar"] is not None:
                entry = capacity[row["pillar"]]
                entry.pillar_envelope = (
                    entry.pillar_envelope or Decimal("0")
                ) + _decimal(row["limit_amount"])
            else:
                category_totals[row["category_id"]] = (
                    category_totals.get(row["category_id"], Decimal("0"))
                    + _decimal(row["limit_amount"])
                )
        if category_totals:
            categories = (
                self.client.table("categories")
                .select("id, pillar")
                .in_("id", list(category_totals))
                .execute()
            )
            category_pillars = {
                row["id"]: row.get("pillar") for row in categories.data
            }
        for category_id, amount in category_totals.items():
            pillar = category_pillars.get(category_id)
            if pillar not in capacity:
                continue
            entry = capacity[pillar]
            entry.category_limit_total += amount
        if total_budget is not None:
            for entry in capacity.values():
                entry.total_budget = total_budget
        return capacity

    def rebalance(self, request: RebalanceRequest) -> RebalanceResult:
        """Apply a rebalance through the single-transaction RPC."""
        allocations = [
            {
                "group_key": item.group_key,
                "pillar": item.pillar,
                "daily_amount": str(item.daily_amount),
            }
            for item in request.allocations
        ]
        purchase: dict[str, Any] = {
            "amount": str(request.purchase_amount),
            "group_key": request.allocations[0].group_key,
        }
        if request.account_id is not None:
            purchase["account_id"] = request.account_id
        if request.category_id is not None:
            purchase["category_id"] = request.category_id
        if request.description:
            purchase["description"] = request.description
        try:
            data = (
                self.client.rpc(
                    "rebalance_plan",
                    {
                        "p_plan_id": request.plan_id,
                        "p_expected_version": request.expected_version,
                        "p_allocations": allocations,
                        "p_purchase": purchase,
                        "p_idempotency_key": str(request.idempotency_key),
                    },
                )
                .execute()
                .data
            )
        except APIError as error:
            raise _rpc_error(error) from error
        if not data:
            raise TransactionError(409, "Rebalance was not applied")
        return RebalanceResult(
            plan_id=int(data["plan_id"]),
            plan_version=int(data["plan_version"]),
            rebalanced=bool(data.get("rebalanced", True)),
            before={
                key: _decimal(value)
                for key, value in (data.get("before") or {}).items()
            },
            after={
                key: _decimal(value)
                for key, value in (data.get("after") or {}).items()
            },
            daily_allowance_before=_decimal(data.get("daily_allowance_before")),
            daily_allowance_after=_decimal(data.get("daily_allowance_after")),
            survival_floor=_decimal(data.get("survival_floor")),
            transaction_id=data.get("transaction_id"),
            warnings=tuple(data.get("warnings") or ()),
        )

    # -- helpers -------------------------------------------------------------

    def _find_by_idempotency_key(self, key: UUID) -> BudgetPlan | None:
        """Return the plan already stored under an idempotency key."""
        result = (
            self.client.table("budget_plans")
            .select("*")
            .eq("user_id", self.user_id)
            .eq("idempotency_key", str(key))
            .execute()
        )
        if not result.data:
            return None
        record = result.data[0]
        return self._to_plan(record, self._groups_from_allocations(record["id"]))

    def _groups_from_allocations(self, plan_id: int) -> tuple[PlanGroup, ...]:
        allocations = self.allocations(plan_id)
        seen: dict[str, PlanGroup] = {}
        for item in allocations:
            if item.group_key in seen:
                continue
            seen[item.group_key] = PlanGroup(
                group_key=item.group_key,
                pillar=item.pillar,
                daily_amount=item.amount,
                total_amount=item.amount,
            )
        return tuple(seen.values())

    @staticmethod
    def _to_plan(record: dict, groups: tuple[PlanGroup, ...]) -> BudgetPlan:
        return BudgetPlan(
            id=int(record["id"]),
            title=record["title"],
            status=record["status"],
            total_income=_decimal(record["total_income"]),
            duration_days=int(record["duration_days"]),
            savings_target=_decimal(record["savings_target"]),
            fixed_expenses=_decimal(record["fixed_expenses"]),
            start_date=date.fromisoformat(record["start_date"]),
            spendable_budget=_decimal(record["spendable_budget"]),
            daily_allowance=_decimal(record["daily_allowance"]),
            survival_floor=_decimal(record.get("survival_floor")),
            plan_version=int(record["plan_version"]),
            config_version=record["config_version"],
            groups=groups,
            idempotency_key=(
                UUID(record["idempotency_key"])
                if record.get("idempotency_key")
                else None
            ),
            created_at=record.get("created_at"),
            updated_at=record.get("updated_at"),
        )


def _rpc_error(error: APIError) -> TransactionError:
    """Translate a database error into an actionable API error.

    The rebalance function raises the PostgREST code `PT409` for a stale
    plan version. A plain `40001` would not work: PostgREST treats a
    serialization failure as transient and retries it forever, so the request
    would hang instead of answering with a conflict.
    """
    code = error.code
    if code in {"PT409", "40001"}:
        return TransactionError(409, "Kế hoạch đã thay đổi, hãy tải lại.")
    if code in {"PT403", "42501"}:
        return TransactionError(403, "Kế hoạch không khả dụng.")
    if code == "23505":
        return TransactionError(409, "Kế hoạch đã tồn tại.")
    if code in {"PT422", "23514", "22023"}:
        return TransactionError(422, error.message)
    return TransactionError(503, "Data service unavailable")


def allocations_from_groups(groups: tuple[PlanGroup, ...]) -> list[PlanAllocation]:
    """Convert plan groups into rebalance allocation entries."""
    return [
        PlanAllocation(
            group_key=group.group_key,
            pillar=group.pillar,
            daily_amount=group.daily_amount,
        )
        for group in groups
    ]
