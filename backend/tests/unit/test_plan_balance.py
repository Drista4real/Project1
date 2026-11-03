"""Tests for the plan balance source that reads confirmed spending."""

from datetime import date
from decimal import Decimal

import httpx
import pytest
from supabase import ClientOptions, create_client

from app.domain.budget_plan import BudgetPlan, GroupRatios, compute_plan_totals
from app.infrastructure.repositories.plan_balance import SupabasePlanBalanceSource


def _plan(**overrides) -> BudgetPlan:
    totals = compute_plan_totals(
        total_income=Decimal("8000000"),
        fixed_expenses=Decimal("3000000"),
        savings_target=Decimal("2000000"),
        duration_days=30,
        group_ratios=GroupRatios(),
    )
    payload = {
        "id": 42,
        "title": "Kế hoạch chi tiêu",
        "status": "ACTIVE",
        "total_income": Decimal("8000000"),
        "duration_days": 30,
        "savings_target": Decimal("2000000"),
        "fixed_expenses": Decimal("3000000"),
        "start_date": date(2026, 11, 1),
        "spendable_budget": totals.spendable_budget,
        "daily_allowance": totals.daily_allowance,
        "survival_floor": totals.survival_floor,
        "plan_version": 1,
        "config_version": "budget-engine-v1",
        "groups": totals.groups,
    }
    payload.update(overrides)
    return BudgetPlan(**payload)


def _client(
    allocations: list[dict], transactions: list[dict]
) -> "create_client":  # type: ignore[valid-type]
    def handle(request):
        path = request.url.path
        if path.endswith("/daily_allocations"):
            rows = allocations
        else:
            rows = transactions
        return httpx.Response(200, json=rows)

    transport = httpx.MockTransport(handle)
    return create_client(
        "https://example.supabase.co",
        "sb_publishable_example",
        options=ClientOptions(httpx_client=httpx.Client(transport=transport)),
    )


class TestPlanBalanceSource:
    """The remaining amount comes from real spending, never an estimate."""

    def test_remaining_is_the_grant_minus_recorded_spending(self):
        source = SupabasePlanBalanceSource(
            _client(
                allocations=[{"day_index": 1}],
                transactions=[{"amount": "500000.00"}],
            ),
            "owner",
        )
        remaining = source.remaining_balance(_plan(), 3)
        assert remaining == Decimal("2500000.00")

    def test_a_plan_without_allocations_has_no_known_balance(self):
        source = SupabasePlanBalanceSource(
            _client(allocations=[], transactions=[]), "owner"
        )
        assert source.remaining_balance(_plan(), 3) is None

    def test_a_day_outside_the_plan_has_no_known_balance(self):
        source = SupabasePlanBalanceSource(
            _client(allocations=[{"day_index": 1}], transactions=[]), "owner"
        )
        assert source.remaining_balance(_plan(), 31) is None
        assert source.remaining_balance(_plan(), 0) is None

    def test_spending_beyond_the_grant_never_goes_negative(self):
        source = SupabasePlanBalanceSource(
            _client(
                allocations=[{"day_index": 1}],
                transactions=[{"amount": "9000000.00"}],
            ),
            "owner",
        )
        assert source.remaining_balance(_plan(), 3) == Decimal("0")

    def test_the_window_reads_only_expenses_of_the_owner(self):
        captured: dict[str, list[str]] = {}

        def handle(request):
            params = request.url.params
            if request.url.path.endswith("/daily_allocations"):
                return httpx.Response(200, json=[{"day_index": 1}])
            for key, value in params.multi_items():
                captured.setdefault(key, []).append(value)
            return httpx.Response(200, json=[])

        client = create_client(
            "https://example.supabase.co",
            "sb_publishable_example",
            options=ClientOptions(
                httpx_client=httpx.Client(transport=httpx.MockTransport(handle))
            ),
        )
        source = SupabasePlanBalanceSource(client, "owner")
        source.remaining_balance(_plan(), 3)

        assert captured["user_id"] == ["eq.owner"]
        assert captured["transaction_type"] == ["eq.expense"]
        assert sorted(captured["transaction_date"]) == [
            "gte.2026-11-01",
            "lt.2026-11-04",
        ]


@pytest.mark.parametrize("day_index", [1, 15, 30])
def test_every_day_of_the_plan_reports_a_known_balance(day_index):
    source = SupabasePlanBalanceSource(
        _client(allocations=[{"day_index": 1}], transactions=[]), "owner"
    )
    remaining = source.remaining_balance(_plan(), day_index)
    assert remaining == Decimal("3000000.00")
