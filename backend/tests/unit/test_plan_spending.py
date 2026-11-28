"""The plan's spending is read from the expenses recorded in the ledger.

A confirmed purchase in the chat also writes a ledger transaction, so the
ledger holds every expense; the stored `actual_spent` column is not added on
top, which would count a confirmed purchase twice.
"""

from datetime import date
from decimal import Decimal
from types import SimpleNamespace

from app.application.budget_plan import BudgetPlanService
from app.domain.budget_plan import (
    DailyAllocation,
    group_for_category,
    spending_by_day_and_group,
    with_recorded_spending,
)
from app.infrastructure.repositories.plan_balance import SupabasePlanBalanceSource

START = date(2026, 11, 13)
FOOD = {"name": "Ăn uống & Đi chợ"}


def _expense(amount: str, moment: str, category=None) -> dict:
    return {"amount": amount, "transaction_date": moment, "categories": category}


def _rows(day: date) -> list[DailyAllocation]:
    return [
        DailyAllocation(
            day_index=(day - START).days + 1,
            alloc_date=day,
            group_key=key,
            pillar="wants" if key == "lifestyle" else "needs",
            amount=Decimal(amount),
            actual_spent=Decimal("0"),
        )
        for key, amount in (
            ("food", "245455"),
            ("transport", "61364"),
            ("lifestyle", "102272"),
        )
    ]


class TestGroupForCategory:
    def test_food_categories_spend_from_food(self):
        assert group_for_category("Ăn uống & Đi chợ") == "food"

    def test_transport_categories_spend_from_transport(self):
        assert group_for_category("Xăng xe & Giao thông") == "transport"

    def test_any_other_expense_spends_from_lifestyle(self):
        assert group_for_category("Hóa đơn điện nước & Internet") == "lifestyle"
        assert group_for_category(None) == "lifestyle"


class TestSpendingByDay:
    def test_expenses_are_summed_by_local_day_and_group(self):
        spending = spending_by_day_and_group(
            [
                _expense("30000", "2026-11-13T05:00:00+00:00", FOOD),
                _expense("20000", "2026-11-13T09:00:00+00:00", FOOD),
                _expense("50000", "2026-11-14T03:00:00+00:00"),
            ]
        )
        assert spending == {
            (date(2026, 11, 13), "food"): Decimal("50000"),
            (date(2026, 11, 14), "lifestyle"): Decimal("50000"),
        }

    def test_the_day_follows_vietnam_time(self):
        # 23:30 UTC on the 13th is 06:30 on the 14th in Vietnam.
        spending = spending_by_day_and_group(
            [_expense("10000", "2026-11-13T23:30:00+00:00")]
        )
        assert spending == {(date(2026, 11, 14), "lifestyle"): Decimal("10000")}


class TestWithRecordedSpending:
    def test_the_ledger_spending_fills_the_matching_rows(self):
        rows = _rows(START) + _rows(date(2026, 11, 14))
        result = with_recorded_spending(
            rows,
            {
                (START, "food"): Decimal("30000"),
                (date(2026, 11, 14), "lifestyle"): Decimal("50000"),
            },
        )
        spent = {(r.alloc_date, r.group_key): r.actual_spent for r in result}
        assert spent[(START, "food")] == Decimal("30000")
        assert spent[(date(2026, 11, 14), "lifestyle")] == Decimal("50000")
        assert spent[(START, "transport")] == Decimal("0")

    def test_the_stored_column_is_not_added_twice(self):
        rows = [
            r.model_copy(update={"actual_spent": Decimal("30000")})
            for r in _rows(START)
        ]
        result = with_recorded_spending(rows, {(START, "food"): Decimal("30000")})
        assert sum(r.actual_spent for r in result) == Decimal("30000")

    def test_a_group_missing_from_the_day_falls_to_the_last_row(self):
        rows = [r for r in _rows(START) if r.group_key != "transport"]
        result = with_recorded_spending(rows, {(START, "transport"): Decimal("15000")})
        assert sum(r.actual_spent for r in result) == Decimal("15000")


class _Repository:
    def get(self, plan_id):
        return SimpleNamespace(id=plan_id, start_date=START, duration_days=2)

    def allocations(self, plan_id):
        return _rows(START) + _rows(date(2026, 11, 14))


class _Spending:
    def __init__(self):
        self.windows: list[tuple[date, date]] = []

    def expenses_between(self, start: date, end: date) -> list[dict]:
        self.windows.append((start, end))
        return [_expense("30000", "2026-11-13T05:00:00+00:00", FOOD)]


class TestServiceAllocations:
    def test_the_projection_shows_what_the_ledger_recorded(self):
        spending = _Spending()
        service = BudgetPlanService(_Repository(), spending_source=spending)
        rows = service.allocations(8)
        food = next(r for r in rows if r.alloc_date == START and r.group_key == "food")
        assert food.actual_spent == Decimal("30000")
        # One day of margin on each side covers the time zone shift.
        assert spending.windows == [(date(2026, 11, 12), date(2026, 11, 16))]

    def test_without_a_source_the_stored_projection_is_returned(self):
        rows = BudgetPlanService(_Repository()).allocations(8)
        assert all(r.actual_spent == 0 for r in rows)


class _Query:
    def __init__(self):
        self.filters: list[tuple] = []
        self.columns = ""

    def select(self, columns="*", **kwargs):
        self.columns = columns
        return self

    def eq(self, column, value):
        self.filters.append(("eq", column, value))
        return self

    def gte(self, column, value):
        self.filters.append(("gte", column, value))
        return self

    def lt(self, column, value):
        self.filters.append(("lt", column, value))
        return self

    def order(self, *args, **kwargs):
        return self

    def execute(self):
        return SimpleNamespace(data=[])


class _Client:
    def __init__(self):
        self.query = _Query()

    def table(self, name):
        assert name == "transactions"
        return self.query


class TestExpenseQuery:
    def test_only_the_owners_expenses_in_the_window_are_read(self):
        client = _Client()
        user = "11111111-1111-4111-8111-111111111111"
        SupabasePlanBalanceSource(client, user).expenses_between(
            date(2026, 11, 12), date(2026, 11, 16)
        )
        filters = client.query.filters
        assert ("eq", "user_id", user) in filters
        assert ("eq", "transaction_type", "expense") in filters
        assert ("gte", "transaction_date", "2026-11-12") in filters
        assert ("lt", "transaction_date", "2026-11-16") in filters
        assert "categories(name)" in client.query.columns
