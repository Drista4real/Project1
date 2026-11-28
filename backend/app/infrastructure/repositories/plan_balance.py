"""Remaining plan budget derived from the user's confirmed transactions.

The purchase impact tool must not estimate a balance. This adapter reads the
plan's own budget and the money the user actually recorded spending inside the
plan window, so the remaining amount is a fact rather than a guess. When the
plan has no allocation rows the balance is unknown and the caller reports
`INSUFFICIENT_DATA` instead of inventing a number (ADR 0009).

Reading recorded spending is not a forecast. The eight-point rule of Model 2
guards extrapolation of a balance series; here the plan's grant and the
confirmed transactions are both read, never projected.
"""

from collections.abc import Callable
from datetime import UTC, date, datetime
from decimal import Decimal

from supabase import Client

from app.domain.budget_plan import (
    LOCAL_TIMEZONE,
    BudgetPlan,
    RemainingBalanceSource,
    exempt_fixed_expenses,
    plan_window_bounds,
)


def _postgrest_moment(moment: datetime) -> str:
    """An aware moment as UTC ending in ``Z``; a ``+`` would need URL encoding."""
    return moment.astimezone(UTC).isoformat().replace("+00:00", "Z")


class SupabasePlanBalanceSource(RemainingBalanceSource):
    """Read how much of the plan is left, from real spending."""

    def __init__(
        self,
        client: Client,
        user_id: str,
        clock: Callable[[], datetime] | None = None,
    ) -> None:
        self.client = client
        self.user_id = user_id
        # The preview moment; current_day from the caller cannot be trusted.
        self.clock = clock or (lambda: datetime.now(LOCAL_TIMEZONE))

    def remaining_balance(self, plan: BudgetPlan, day_index: int) -> Decimal | None:
        """Return the money left in the plan on a given day.

        The plan grants a spendable budget over its window. The money already
        used is the confirmed spending recorded from 00:00 of the start day in
        Vietnam up to the preview moment, so the remainder is the grant minus
        what the user really spent. Spending beyond the grant gives a negative
        remainder, the size of the deficit.
        """
        if day_index < 1 or day_index > plan.duration_days:
            return None
        if not self._has_allocations(plan.id):
            return None
        start, end = plan_window_bounds(
            plan.start_date, plan.duration_days, self.clock()
        )
        spent = self._spent_between(start, end, plan) if start < end else Decimal("0")
        return plan.spendable_budget - spent

    def _has_allocations(self, plan_id: int) -> bool:
        """Report whether the plan has a daily projection to read."""
        result = (
            self.client.table("daily_allocations")
            .select("day_index")
            .eq("plan_id", plan_id)
            .limit(1)
            .execute()
        )
        return bool(result.data)

    def expenses_between(self, start: date, end: date) -> list[dict]:
        """The owner's ledger expenses from ``start`` up to ``end``."""
        result = (
            self.client.table("transactions")
            .select("amount, transaction_date, categories(name)")
            .eq("user_id", self.user_id)
            .eq("transaction_type", "expense")
            .gte("transaction_date", start.isoformat())
            .lt("transaction_date", end.isoformat())
            .order("transaction_date")
            .execute()
        )
        return result.data or []

    def _spent_between(
        self, start: datetime, end: datetime, plan: BudgetPlan
    ) -> Decimal:
        """Sum the expenses inside ``[start, end)``, less this plan's fixed ones.

        The bounds are sent as UTC moments, so the result does not depend on
        the TimeZone of the database session.
        """
        result = (
            self.client.table("transactions")
            .select("amount, fixed_expense_plan_id")
            .eq("user_id", self.user_id)
            .eq("transaction_type", "expense")
            .gte("transaction_date", _postgrest_moment(start))
            .lt("transaction_date", _postgrest_moment(end))
            .execute()
        )
        rows = result.data or []
        total = sum((Decimal(str(row["amount"])) for row in rows), Decimal("0"))
        # A marker for another plan is ordinary spending of this one.
        marked = sum(
            (
                Decimal(str(row["amount"]))
                for row in rows
                if row.get("fixed_expense_plan_id") == plan.id
            ),
            Decimal("0"),
        )
        return exempt_fixed_expenses(total, marked, plan.fixed_expenses)
