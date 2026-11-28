"""Tests for the monthly setup: the next income date, the preview and the
defaults that prefill the first-login setup (docs/monthly-setup/PLAN.md).
"""

from datetime import date, timedelta
from decimal import Decimal
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import UserContext, get_user_context
from app.api.v1.endpoints.budget_plans import (
    get_budget_plan_service,
    get_setup_defaults_service,
)
from app.application.budget_plan import (
    PLAN_NOT_FUNDED_MESSAGE,
    BudgetPlanService,
    SetupDefaultsService,
)
from app.domain.budget_plan import BudgetPlanCreateInput, next_income_date
from app.domain.transactions import TransactionError
from app.infrastructure.repositories.setup_defaults import (
    SupabaseSetupDefaultsSource,
)
from app.main import app

TODAY = date(2026, 11, 12)


class TestNextIncomeDate:
    """The day the plan ends: the next fixed income."""

    def test_the_earliest_recurring_income_wins(self):
        result = next_income_date(
            TODAY,
            [(date(2026, 12, 10), "Thưởng"), (date(2026, 12, 1), "Lương")],
            payroll_day=5,
        )
        assert result.date == date(2026, 12, 1)
        assert result.source == "recurring"
        assert result.label == "Lương"

    def test_a_recurring_income_due_today_is_not_the_next_one(self):
        result = next_income_date(TODAY, [(TODAY, "Lương")], payroll_day=None)
        assert result.date is None
        assert result.source == "none"

    def test_the_payroll_day_is_used_without_a_recurring_income(self):
        result = next_income_date(TODAY, [], payroll_day=5)
        assert result.date == date(2026, 12, 5)
        assert result.source == "payroll_day"
        assert result.label is None

    def test_a_payroll_day_later_this_month_is_kept(self):
        result = next_income_date(TODAY, [], payroll_day=25)
        assert result.date == date(2026, 11, 25)

    def test_a_day_the_month_lacks_falls_on_its_last_day(self):
        result = next_income_date(date(2026, 11, 20), [], payroll_day=31)
        assert result.date == date(2026, 11, 30)

    def test_the_payroll_day_rolls_over_the_year(self):
        result = next_income_date(date(2026, 12, 20), [], payroll_day=5)
        assert result.date == date(2027, 1, 5)

    def test_an_income_three_days_away_moves_to_the_next_cycle(self):
        result = next_income_date(date(2026, 11, 2), [], payroll_day=5)
        assert result.date == date(2026, 12, 5)

    def test_an_income_four_days_away_is_kept(self):
        result = next_income_date(date(2026, 11, 1), [], payroll_day=5)
        assert result.date == date(2026, 11, 5)

    def test_a_close_recurring_income_gives_way_to_a_later_one(self):
        result = next_income_date(
            TODAY,
            [(date(2026, 11, 14), "Lương"), (date(2026, 12, 14), "Lương")],
            payroll_day=None,
        )
        assert result.date == date(2026, 12, 14)

    def test_a_close_recurring_income_falls_back_to_the_payroll_day(self):
        result = next_income_date(
            TODAY, [(date(2026, 11, 13), "Lương")], payroll_day=5
        )
        assert result.date == date(2026, 12, 5)
        assert result.source == "payroll_day"

    def test_nothing_known_leaves_the_date_open(self):
        result = next_income_date(TODAY, [], payroll_day=None)
        assert (result.date, result.source, result.label) == (None, "none", None)


def _input(**overrides) -> BudgetPlanCreateInput:
    values = {
        "total_income": Decimal("8000000"),
        "duration_days": 23,
        "savings_target": Decimal("800000"),
        "fixed_expenses": Decimal("3100000"),
        "start_date": TODAY,
    }
    values.update(overrides)
    return BudgetPlanCreateInput(**values)


class _NoWriteRepository:
    """A repository that fails the test if anything is written."""

    def create(self, plan, allocations):
        raise AssertionError("the preview must not save a plan")


class TestPreview:
    """The preview runs the engine and saves nothing."""

    def test_the_preview_returns_the_engine_figures(self):
        totals = BudgetPlanService(_NoWriteRepository()).preview(_input())
        assert totals.spendable_budget == Decimal("4100000.00")
        assert totals.daily_allowance == Decimal("178260.87")
        assert totals.survival_floor == Decimal("134782.61")
        assert sum(group.total_amount for group in totals.groups) == Decimal(
            "4100000.00"
        )

    def test_an_unfunded_plan_is_refused_in_vietnamese(self):
        service = BudgetPlanService(_NoWriteRepository())
        with pytest.raises(TransactionError) as caught:
            service.preview(_input(total_income=Decimal("3000000")))
        assert caught.value.status == 422
        assert caught.value.message == PLAN_NOT_FUNDED_MESSAGE


class _FakeSource:
    """What the database knows about one user."""

    def __init__(self, **overrides):
        self.balance = overrides.get("balance", "8000000.00")
        self.income = overrides.get("income", [])
        self.expenses = overrides.get(
            "expenses",
            [
                {
                    "description": "Tiền nhà",
                    "amount": "2500000.00",
                    "next_execution_date": "2026-12-01",
                },
                {
                    "description": "Điện nước",
                    "amount": "600000.00",
                    "next_execution_date": "2026-11-25",
                },
            ],
        )
        self.profile_row = overrides.get(
            "profile", {"payroll_day": 5, "monthly_savings_target": "0.00"}
        )
        self.plans = overrides.get("plans", False)
        self.expense_windows: list[tuple[date, date]] = []

    def available_balance(self) -> str:
        return self.balance

    def recurring_income(self, after: date) -> list[dict]:
        return [
            row
            for row in self.income
            if date.fromisoformat(row["next_execution_date"]) > after
        ]

    def recurring_expenses(self, start: date, end: date) -> list[dict]:
        self.expense_windows.append((start, end))
        return [
            row
            for row in self.expenses
            if start <= date.fromisoformat(row["next_execution_date"]) <= end
        ]

    def profile(self) -> dict:
        return self.profile_row

    def has_plans(self) -> bool:
        return self.plans


class TestSetupDefaults:
    """The answers the server can prefill."""

    def test_the_defaults_combine_wallets_income_and_fixed_costs(self):
        defaults = SetupDefaultsService(_FakeSource()).load(TODAY)
        assert defaults.available_balance == Decimal("8000000.00")
        assert defaults.next_income_date == date(2026, 12, 5)
        assert defaults.next_income_source == "payroll_day"
        assert [item.description for item in defaults.fixed_expenses] == [
            "Điện nước",
            "Tiền nhà",
        ]
        assert defaults.fixed_expenses[0].next_date == date(2026, 11, 25)
        assert defaults.monthly_savings_target == Decimal("0.00")
        assert defaults.has_plans is False

    def test_fixed_costs_are_read_until_the_next_income(self):
        source = _FakeSource()
        SetupDefaultsService(source).load(TODAY)
        assert source.expense_windows == [(TODAY, date(2026, 12, 5))]

    def test_without_an_income_date_thirty_days_are_read(self):
        source = _FakeSource(profile={"payroll_day": None})
        defaults = SetupDefaultsService(source).load(TODAY)
        assert defaults.next_income_date is None
        assert source.expense_windows == [(TODAY, TODAY + timedelta(days=30))]

    def test_a_recurring_income_names_its_source(self):
        source = _FakeSource(
            income=[{"description": "Lương", "next_execution_date": "2026-11-28"}]
        )
        defaults = SetupDefaultsService(source).load(TODAY)
        assert defaults.next_income_date == date(2026, 11, 28)
        assert defaults.next_income_source == "recurring"
        assert defaults.next_income_label == "Lương"

    def test_a_missing_profile_still_answers(self):
        defaults = SetupDefaultsService(_FakeSource(profile={})).load(TODAY)
        assert defaults.monthly_savings_target == Decimal("0")
        assert defaults.next_income_source == "none"


class _Query:
    """A chainable PostgREST query double that records its filters."""

    def __init__(self, data):
        self.data = data
        self.filters: list[tuple] = []

    def select(self, *args, **kwargs):
        return self

    def eq(self, column, value):
        self.filters.append(("eq", column, value))
        return self

    def gt(self, column, value):
        self.filters.append(("gt", column, value))
        return self

    def gte(self, column, value):
        self.filters.append(("gte", column, value))
        return self

    def lte(self, column, value):
        self.filters.append(("lte", column, value))
        return self

    def order(self, *args, **kwargs):
        return self

    def range(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def maybe_single(self):
        return self

    def execute(self):
        return SimpleNamespace(data=self.data)


class _Client:
    def __init__(self, data):
        self.data = data
        self.queries: dict[str, list[_Query]] = {}

    def table(self, name):
        query = _Query(self.data.get(name, []))
        self.queries.setdefault(name, []).append(query)
        return query


USER = "11111111-1111-4111-8111-111111111111"


class TestSetupDefaultsSource:
    """Every query is scoped to the signed-in owner."""

    def test_recurring_income_is_read_for_the_owner_only(self):
        client = _Client({"recurring_transactions": []})
        SupabaseSetupDefaultsSource(client, USER).recurring_income(TODAY)
        filters = client.queries["recurring_transactions"][0].filters
        assert ("eq", "user_id", USER) in filters
        assert ("eq", "transaction_type", "income") in filters
        assert ("eq", "is_active", True) in filters
        assert ("gt", "next_execution_date", "2026-11-12") in filters

    def test_recurring_expenses_are_read_inside_the_window(self):
        client = _Client({"recurring_transactions": []})
        SupabaseSetupDefaultsSource(client, USER).recurring_expenses(
            TODAY, date(2026, 12, 5)
        )
        filters = client.queries["recurring_transactions"][0].filters
        assert ("eq", "user_id", USER) in filters
        assert ("eq", "transaction_type", "expense") in filters
        assert ("eq", "is_active", True) in filters
        assert ("gte", "next_execution_date", "2026-11-12") in filters
        assert ("lte", "next_execution_date", "2026-12-05") in filters

    def test_the_profile_and_plans_are_read_for_the_owner(self):
        client = _Client(
            {"profiles": {"payroll_day": 5}, "budget_plans": [{"id": 3}]}
        )
        source = SupabaseSetupDefaultsSource(client, USER)
        assert source.profile() == {"payroll_day": 5}
        assert source.has_plans() is True
        assert ("eq", "id", USER) in client.queries["profiles"][0].filters
        assert ("eq", "user_id", USER) in client.queries["budget_plans"][0].filters

    def test_an_absent_profile_reads_as_empty(self):
        client = _Client({"profiles": None, "budget_plans": []})
        source = SupabaseSetupDefaultsSource(client, USER)
        assert source.profile() == {}
        assert source.has_plans() is False


@pytest.fixture
def client():
    """A test client with an in-memory engine and an in-memory setup source."""

    async def fake_context():
        yield UserContext(client=None, user_id="user-1")

    app.dependency_overrides[get_user_context] = fake_context
    app.dependency_overrides[get_budget_plan_service] = lambda: BudgetPlanService(
        _NoWriteRepository()
    )
    # The endpoint reads the server's own day, so the data follows the clock.
    soon = (date.today() + timedelta(days=5)).isoformat()
    source = _FakeSource(
        expenses=[
            {
                "description": "Tiền nhà",
                "amount": "2500000.00",
                "next_execution_date": soon,
            }
        ]
    )
    app.dependency_overrides[get_setup_defaults_service] = lambda: (
        SetupDefaultsService(source)
    )
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


PREVIEW_BODY = {
    "title": "Kế hoạch tháng",
    "total_income": "8000000.00",
    "duration_days": 23,
    "savings_target": "800000.00",
    "fixed_expenses": "3100000.00",
    "group_ratios": {"food": 60, "transport": 15, "lifestyle": 25},
    "start_date": "2026-11-12",
}


class TestMonthlySetupEndpoints:
    """The two read-only endpoints the setup screen calls."""

    def test_the_preview_answers_with_the_engine_figures(self, client):
        response = client.post("/api/v1/budget-plans/preview", json=PREVIEW_BODY)
        assert response.status_code == 200
        body = response.json()
        assert body["spendable_budget"] == "4100000.00"
        assert body["daily_allowance"] == "178260.87"
        assert body["survival_floor"] == "134782.61"
        assert [group["group_key"] for group in body["groups"]] == [
            "food",
            "transport",
            "lifestyle",
        ]

    def test_an_unfunded_preview_explains_why_in_vietnamese(self, client):
        response = client.post(
            "/api/v1/budget-plans/preview",
            json={**PREVIEW_BODY, "total_income": "3000000.00"},
        )
        assert response.status_code == 422
        assert response.json()["detail"] == PLAN_NOT_FUNDED_MESSAGE

    def test_a_plan_longer_than_a_year_is_refused(self, client):
        response = client.post(
            "/api/v1/budget-plans/preview",
            json={**PREVIEW_BODY, "duration_days": 366},
        )
        assert response.status_code == 422

    def test_the_setup_defaults_are_returned(self, client):
        response = client.get(
            "/api/v1/budget-plans/setup-defaults",
            params={"today": date.today().isoformat()},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["available_balance"] == "8000000.00"
        assert body["next_income_source"] in {"payroll_day", "recurring", "none"}
        assert body["has_plans"] is False
        assert set(body["fixed_expenses"][0]) == {"description", "amount", "next_date"}

    def test_a_client_day_far_from_the_server_day_is_refused(self, client):
        response = client.get(
            "/api/v1/budget-plans/setup-defaults", params={"today": "2020-01-01"}
        )
        assert response.status_code == 422

    def test_the_setup_route_is_not_read_as_a_plan_id(self, client):
        # Without a pinned day the server's own date is used.
        response = client.get("/api/v1/budget-plans/setup-defaults")
        assert response.status_code == 200

    def test_the_setup_defaults_need_a_signed_in_user(self):
        with TestClient(app) as anonymous:
            response = anonymous.get("/api/v1/budget-plans/setup-defaults")
        assert response.status_code == 401
