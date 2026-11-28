"""Tests for the plan balance source that reads confirmed spending."""

from collections.abc import Callable
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import get_args

import httpx
import pytest
from supabase import Client, ClientOptions, create_client

from app.domain.budget_plan import (
    LOCAL_TIMEZONE,
    BudgetPlan,
    GroupRatios,
    ImpactLevel,
    compute_plan_totals,
    evaluate_purchase_impact,
)
from app.infrastructure.repositories.plan_balance import SupabasePlanBalanceSource

#: A preview moment inside the plan (day 10), so no test reads the real clock.
AS_OF = datetime(2026, 11, 10, 12, 0, tzinfo=LOCAL_TIMEZONE)


def _plan(**overrides) -> BudgetPlan:
    """A 30-day plan from 2026-11-01 with a 3,000,000 spendable budget."""
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


def _mock_client(handle: Callable[[httpx.Request], httpx.Response]) -> Client:
    """A Supabase client whose HTTP calls are answered by ``handle``."""
    return create_client(
        "https://example.supabase.co",
        "sb_publishable_example",
        options=ClientOptions(
            httpx_client=httpx.Client(transport=httpx.MockTransport(handle))
        ),
    )


def _client(allocations: list[dict], transactions: list[dict]) -> Client:
    """A client that returns the same rows whatever the filters are."""

    def handle(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        rows = allocations if path.endswith("/daily_allocations") else transactions
        return httpx.Response(200, json=rows)

    return _mock_client(handle)


def _source(
    client: Client, clock: Callable[[], datetime] = lambda: AS_OF
) -> SupabasePlanBalanceSource:
    """The adapter for the owner, previewed at a fixed moment."""
    return SupabasePlanBalanceSource(client, "owner", clock=clock)


def _as_utc_session(value: str) -> datetime:
    """Read a timestamptz literal as Postgres does with ``TimeZone = UTC``.

    A literal without an offset, such as ``2026-11-01``, is midnight UTC; a
    literal with an offset or ``Z`` is that exact moment.
    """
    moment = datetime.fromisoformat(value)
    return moment if moment.tzinfo else moment.replace(tzinfo=UTC)


class UtcSessionPostgrest:
    """A PostgREST stand-in whose database session runs with TimeZone = UTC.

    It applies the ``user_id``, ``transaction_type`` and ``transaction_date``
    filters of each request to its rows, and records every transaction read.
    """

    def __init__(self, transactions: list[dict]) -> None:
        self.transactions = transactions
        self.reads: list[httpx.QueryParams] = []

    def handle(self, request: httpx.Request) -> httpx.Response:
        """Answer one request the way the database would."""
        if request.url.path.endswith("/daily_allocations"):
            return httpx.Response(200, json=[{"day_index": 1}])
        params = request.url.params
        self.reads.append(params)
        kept = [row for row in self.transactions if self._matches(row, params)]
        return httpx.Response(200, json=kept)

    @staticmethod
    def _matches(row: dict, params: httpx.QueryParams) -> bool:
        """Apply the equality and date filters of a request to one row."""
        for column in ("user_id", "transaction_type"):
            wanted = params.get(column)
            default = "owner" if column == "user_id" else "expense"
            if wanted and row.get(column, default) != wanted.removeprefix("eq."):
                return False
        moment = _as_utc_session(row["transaction_date"])
        for bound in params.get_list("transaction_date"):
            operator, _, value = bound.partition(".")
            limit = _as_utc_session(value)
            if operator == "gte" and not moment >= limit:
                return False
            if operator == "lt" and not moment < limit:
                return False
        return True

    def client(self) -> Client:
        """A Supabase client wired to this stand-in."""
        return _mock_client(self.handle)


def _expense(utc_moment: str, amount: str = "500000.00") -> dict:
    """A ledger expense stored at a UTC moment, as timestamptz returns it."""
    return {
        "amount": amount,
        "fixed_expense_plan_id": None,
        "transaction_date": utc_moment,
    }


class TestPlanBalanceSource:
    """The remaining amount comes from real spending, never an estimate."""

    def test_remaining_is_the_grant_minus_recorded_spending(self):
        source = _source(
            _client(
                allocations=[{"day_index": 1}],
                transactions=[{"amount": "500000.00"}],
            )
        )
        remaining = source.remaining_balance(_plan(), 3)
        assert remaining == Decimal("2500000.00")

    def test_a_plan_without_allocations_has_no_known_balance(self):
        source = _source(_client(allocations=[], transactions=[]))
        assert source.remaining_balance(_plan(), 3) is None

    def test_a_day_outside_the_plan_has_no_known_balance(self):
        source = _source(_client(allocations=[{"day_index": 1}], transactions=[]))
        assert source.remaining_balance(_plan(), 31) is None
        assert source.remaining_balance(_plan(), 0) is None

    def test_spending_beyond_the_grant_is_kept_negative(self):
        source = _source(
            _client(
                allocations=[{"day_index": 1}],
                transactions=[{"amount": "9000000.00"}],
            )
        )
        remaining = source.remaining_balance(_plan(), 3)
        assert isinstance(remaining, Decimal)
        assert remaining == Decimal("-6000000.00")

    def test_a_negative_remaining_balance_is_critical_danger(self):
        source = _source(
            _client(
                allocations=[{"day_index": 1}],
                transactions=[{"amount": "9000000.00"}],
            )
        )
        plan = _plan()
        impact = evaluate_purchase_impact(
            plan=plan,
            current_day=10,
            amount=Decimal("100000"),
            remaining_balance=source.remaining_balance(plan, 10),
        )
        assert impact.level == "CRITICAL_DANGER"
        assert impact.daily_allowance_after < 0

    def test_the_impact_levels_are_unchanged(self):
        assert set(get_args(ImpactLevel)) == {
            "SAFE",
            "WARNING_REBALANCE_NEEDED",
            "CRITICAL_DANGER",
            "INSUFFICIENT_DATA",
        }

    def test_a_marked_fixed_expense_of_this_plan_is_exempted(self):
        source = _source(
            _client(
                allocations=[{"day_index": 1}],
                transactions=[
                    {"amount": "400000.00", "fixed_expense_plan_id": None},
                    {"amount": "2500000.00", "fixed_expense_plan_id": 42},
                ],
            )
        )
        assert source.remaining_balance(_plan(), 3) == Decimal("2600000.00")

    def test_a_fixed_expense_marked_for_another_plan_still_counts(self):
        source = _source(
            _client(
                allocations=[{"day_index": 1}],
                transactions=[
                    {"amount": "400000.00", "fixed_expense_plan_id": None},
                    {"amount": "2500000.00", "fixed_expense_plan_id": 7},
                ],
            )
        )
        assert source.remaining_balance(_plan(), 3) == Decimal("100000.00")

    def test_a_marker_dated_before_the_plan_is_not_exempted(self):
        inside = [
            _expense("2026-11-02T08:00:00+00:00", "400000.00"),
            {
                **_expense("2026-11-02T09:00:00+00:00", "2500000.00"),
                "fixed_expense_plan_id": 42,
            },
        ]
        before_start = {
            **_expense("2026-10-31T09:00:00+00:00", "1000000.00"),
            "fixed_expense_plan_id": 42,
        }

        without = _source(UtcSessionPostgrest(inside).client())
        with_marker = _source(UtcSessionPostgrest([*inside, before_start]).client())
        # E = 2.9M - min(2.5M, 3M) = 400k; counting the earlier row would
        # give 3.9M - min(3.5M, 3M) = 900k and a remainder of 2.1M.
        assert without.remaining_balance(_plan(), 3) == Decimal("2600000.00")
        assert with_marker.remaining_balance(_plan(), 3) == Decimal("2600000.00")

    def test_the_window_reads_only_expenses_of_the_owner(self):
        database = UtcSessionPostgrest([])
        _source(database.client()).remaining_balance(_plan(), 3)

        (params,) = database.reads
        assert params.get_list("user_id") == ["eq.owner"]
        assert params.get_list("transaction_type") == ["eq.expense"]


class TestPlanWindowInHoChiMinhTime:
    """E is read from 00:00 of the start day in Vietnam up to the preview.

    The database session runs with ``TimeZone = UTC``, so a bare date sent
    as a bound would mean 07:00 in Ho Chi Minh City.
    """

    def test_an_expense_at_half_past_midnight_on_the_first_day_counts(self):
        # 2026-11-01 00:30 in Ho Chi Minh City.
        database = UtcSessionPostgrest([_expense("2026-10-31T17:30:00+00:00")])
        remaining = _source(database.client()).remaining_balance(_plan(), 3)
        assert remaining == Decimal("2500000.00")

    def test_an_expense_late_the_night_before_the_plan_does_not_count(self):
        # 2026-10-31 23:30 in Ho Chi Minh City, the day before the plan.
        database = UtcSessionPostgrest([_expense("2026-10-31T16:30:00+00:00")])
        remaining = _source(database.client()).remaining_balance(_plan(), 3)
        assert remaining == Decimal("3000000.00")

    def test_an_expense_at_half_past_eleven_belongs_to_its_own_day(self):
        # 2026-11-05 23:30 in Ho Chi Minh City is still day 5 of the plan.
        database = UtcSessionPostgrest([_expense("2026-11-05T16:30:00+00:00")])
        late_on_day_5 = datetime(2026, 11, 5, 23, 45, tzinfo=LOCAL_TIMEZONE)
        early_on_day_5 = datetime(2026, 11, 5, 23, 15, tzinfo=LOCAL_TIMEZONE)

        counted = _source(database.client(), lambda: late_on_day_5)
        not_yet = _source(database.client(), lambda: early_on_day_5)
        assert counted.remaining_balance(_plan(), 5) == Decimal("2500000.00")
        assert not_yet.remaining_balance(_plan(), 5) == Decimal("3000000.00")

    def test_an_expense_just_after_the_preview_does_not_count(self):
        # AS_OF is 2026-11-10 12:00 in Ho Chi Minh City (05:00 UTC).
        database = UtcSessionPostgrest(
            [
                _expense("2026-11-10T04:59:59+00:00", "300000.00"),
                _expense("2026-11-10T05:00:01+00:00", "700000.00"),
            ]
        )
        remaining = _source(database.client()).remaining_balance(_plan(), 10)
        assert remaining == Decimal("2700000.00")

    def test_an_expense_after_the_plan_ends_does_not_count(self):
        # The plan ends at 2026-12-01 00:00 in Ho Chi Minh City.
        database = UtcSessionPostgrest(
            [
                _expense("2026-11-30T16:30:00+00:00", "300000.00"),
                _expense("2026-11-30T17:30:00+00:00", "700000.00"),
            ]
        )
        after_the_plan = datetime(2026, 12, 15, 9, 0, tzinfo=LOCAL_TIMEZONE)
        source = _source(database.client(), lambda: after_the_plan)
        assert source.remaining_balance(_plan(), 30) == Decimal("2700000.00")

    def test_a_preview_before_the_plan_starts_reads_no_spending(self):
        database = UtcSessionPostgrest([_expense("2026-10-31T16:30:00+00:00")])
        before_the_plan = datetime(2026, 10, 31, 20, 0, tzinfo=LOCAL_TIMEZONE)
        source = _source(database.client(), lambda: before_the_plan)

        assert source.remaining_balance(_plan(), 1) == Decimal("3000000.00")
        assert database.reads == []

    def test_a_clock_without_a_timezone_is_rejected(self):
        database = UtcSessionPostgrest([])
        source = _source(database.client(), lambda: datetime(2026, 11, 10, 12, 0))
        with pytest.raises(ValueError):
            source.remaining_balance(_plan(), 10)

    def test_the_bounds_sent_are_moments_with_a_timezone(self):
        database = UtcSessionPostgrest([])
        _source(database.client()).remaining_balance(_plan(), 10)

        (params,) = database.reads
        filters = params.get_list("transaction_date")
        bounds = dict(bound.partition(".")[::2] for bound in filters)
        start = datetime.fromisoformat(bounds["gte"])
        end = datetime.fromisoformat(bounds["lt"])
        assert start.tzinfo is not None and end.tzinfo is not None
        assert start == datetime(2026, 11, 1, 0, 0, tzinfo=LOCAL_TIMEZONE)
        assert end == AS_OF


@pytest.mark.parametrize("day_index", [1, 15, 30])
def test_every_day_of_the_plan_reports_a_known_balance(day_index):
    source = _source(_client(allocations=[{"day_index": 1}], transactions=[]))
    remaining = source.remaining_balance(_plan(), day_index)
    assert remaining == Decimal("3000000.00")
