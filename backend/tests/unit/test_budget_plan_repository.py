"""Tests for the budget plan persistence port.

Two behaviours of the budget engine can only be proven at the database
boundary, so they are pinned here as well as in the end-to-end suite:

* a stale ``plan_version`` is refused with HTTP 409, and
* a repeated ``idempotency_key`` returns the stored plan instead of writing
  a second one.

The doubles below speak the same chainable PostgREST dialect the real
client uses, so the assertions describe the queries the repository really
issues.
"""

from datetime import date
from decimal import Decimal
from unittest.mock import Mock
from uuid import uuid4

import pytest
from postgrest.exceptions import APIError

from app.domain.budget_plan import (
    BudgetPlan,
    DailyAllocation,
    PlanAllocation,
    PlanGroup,
    RebalanceRequest,
    RebalanceResult,
)
from app.domain.transactions import TransactionError
from app.infrastructure.repositories.budget_plans import (
    SupabaseBudgetPlanRepository,
    _rpc_error,
)

USER = "11111111-1111-4111-8111-111111111111"


class _Query:
    """A chainable PostgREST query double."""

    def __init__(self, result=None, error=None):
        self.result = result
        self.error = error
        self.inserted: list[dict] = []
        self.filters: list[tuple] = []

    def select(self, columns="*", **kwargs):
        return self

    def eq(self, column, value):
        self.filters.append((column, value))
        return self

    def order(self, *args, **kwargs):
        return self

    def range(self, *args, **kwargs):
        return self

    def insert(self, payload):
        self.inserted.append(payload)
        return self

    def execute(self):
        if self.error is not None:
            error = self.error
            self.error = None
            raise error
        return self.result


class _RpcQuery:
    """A query double for the rebalance RPC."""

    def __init__(self, result=None, error=None):
        self.result = result
        self.error = error
        self.payload: dict | None = None

    def execute(self):
        if self.error is not None:
            error = self.error
            self.error = None
            raise error
        return self.result


class _Client:
    """A Supabase client double that hands out prepared queries."""

    def __init__(self, queries=(), rpc=None):
        self.queries = list(queries)
        self.rpc_query = rpc
        self.requested: list[str] = []
        self.rpc_payloads: list[dict] = []

    def table(self, name):
        self.requested.append(name)
        return self.queries.pop(0)

    def rpc(self, name, payload):
        self.rpc_payloads.append({"name": name, "payload": payload})
        return self.rpc_query


def _result(data):
    result = Mock()
    result.data = data
    result.count = len(data) if data else 0
    return result


def _plan(**overrides) -> BudgetPlan:
    payload = {
        "id": 0,
        "title": "Kế hoạch chi tiêu",
        "status": "ACTIVE",
        "total_income": Decimal("8000000"),
        "duration_days": 7,
        "savings_target": Decimal("1000000"),
        "fixed_expenses": Decimal("1400000"),
        "start_date": date(2026, 11, 1),
        "spendable_budget": Decimal("5600000"),
        "daily_allowance": Decimal("800000"),
        "survival_floor": Decimal("200000"),
        "plan_version": 1,
        "config_version": "budget-engine-v1",
        "groups": (
            PlanGroup(
                group_key="food",
                pillar="needs",
                daily_amount=Decimal("480000"),
                total_amount=Decimal("3360000"),
            ),
        ),
    }
    payload.update(overrides)
    return BudgetPlan(**payload)


def _stored_plan(**overrides) -> dict:
    """The row shape the database returns for a stored plan."""
    payload = {
        "id": 42,
        "title": "Kế hoạch chi tiêu",
        "status": "ACTIVE",
        "total_income": "8000000.00",
        "duration_days": 7,
        "savings_target": "1000000.00",
        "fixed_expenses": "1400000.00",
        "start_date": "2026-11-01",
        "spendable_budget": "5600000.00",
        "daily_allowance": "800000.00",
        "survival_floor": "200000.00",
        "plan_version": 1,
        "config_version": "budget-engine-v1",
        "idempotency_key": None,
        "created_at": "2026-11-01T00:00:00+00:00",
        "updated_at": "2026-11-01T00:00:00+00:00",
    }
    payload.update(overrides)
    return payload


def _allocation() -> DailyAllocation:
    return DailyAllocation(
        day_index=1,
        alloc_date=date(2026, 11, 1),
        group_key="food",
        pillar="needs",
        amount=Decimal("480000"),
        actual_spent=Decimal("0"),
    )


class TestRpcErrorMapping:
    """The database error codes become the documented HTTP statuses."""

    def test_a_stale_plan_version_is_a_conflict(self):
        error = APIError(
            {"code": "40001", "message": "Kế hoạch đã thay đổi, hãy tải lại."}
        )
        translated = _rpc_error(error)
        assert translated.status == 409
        assert translated.message == "Kế hoạch đã thay đổi, hãy tải lại."

    def test_a_missing_plan_is_forbidden(self):
        error = APIError({"code": "42501", "message": "Kế hoạch không khả dụng."})
        translated = _rpc_error(error)
        assert translated.status == 403

    def test_a_duplicate_key_is_a_conflict(self):
        error = APIError({"code": "23505", "message": "duplicate key"})
        translated = _rpc_error(error)
        assert translated.status == 409

    def test_a_check_violation_is_unprocessable(self):
        error = APIError({"code": "23514", "message": "Tổng hạn mức vượt trụ cột"})
        translated = _rpc_error(error)
        assert translated.status == 422
        assert translated.message == "Tổng hạn mức vượt trụ cột"

    def test_an_invalid_parameter_is_unprocessable(self):
        error = APIError({"code": "22023", "message": "Thiếu idempotency key."})
        translated = _rpc_error(error)
        assert translated.status == 422

    def test_an_unknown_error_is_a_service_outage(self):
        error = APIError({"code": "57P01", "message": "admin shutdown"})
        translated = _rpc_error(error)
        assert translated.status == 503


class TestRebalanceVersionConflict:
    """A stale version never overwrites a newer plan."""

    def _request(self) -> RebalanceRequest:
        return RebalanceRequest(
            plan_id=42,
            expected_version=1,
            current_day=1,
            purchase_amount=Decimal("0"),
            allocations=(
                PlanAllocation(
                    group_key="food",
                    pillar="needs",
                    daily_amount=Decimal("480000"),
                ),
            ),
            idempotency_key=uuid4(),
        )

    def test_a_stale_version_raises_a_conflict(self):
        rpc = _RpcQuery(
            error=APIError(
                {
                    "code": "40001",
                    "message": "Kế hoạch đã thay đổi, hãy tải lại.",
                }
            )
        )
        client = _Client(rpc=rpc)
        repository = SupabaseBudgetPlanRepository(client, USER)

        with pytest.raises(TransactionError) as caught:
            repository.rebalance(self._request())

        assert caught.value.status == 409
        assert caught.value.message == "Kế hoạch đã thay đổi, hãy tải lại."

    def test_the_rpc_receives_the_expected_version(self):
        rpc = _RpcQuery(
            result=_result(
                {
                    "plan_id": 42,
                    "plan_version": 2,
                    "rebalanced": True,
                    "before": {"food": "480000.00"},
                    "after": {"food": "400000.00"},
                    "daily_allowance_before": "800000.00",
                    "daily_allowance_after": "700000.00",
                    "survival_floor": "200000.00",
                    "transaction_id": None,
                }
            )
        )
        client = _Client(rpc=rpc)
        repository = SupabaseBudgetPlanRepository(client, USER)
        request = self._request()

        result = repository.rebalance(request)

        assert isinstance(result, RebalanceResult)
        assert result.plan_version == 2
        call = client.rpc_payloads[0]
        assert call["name"] == "rebalance_plan"
        assert call["payload"]["p_expected_version"] == 1
        assert call["payload"]["p_idempotency_key"] == str(request.idempotency_key)

    def test_an_empty_result_is_a_conflict(self):
        rpc = _RpcQuery(result=_result(None))
        client = _Client(rpc=rpc)
        repository = SupabaseBudgetPlanRepository(client, USER)

        with pytest.raises(TransactionError) as caught:
            repository.rebalance(self._request())

        assert caught.value.status == 409


class TestIdempotentPlanCreation:
    """A repeated idempotency key never stores a second plan."""

    def test_the_key_is_written_with_the_plan(self):
        lookup = _Query(result=_result([]))
        insert = _Query(result=_result([_stored_plan()]))
        allocations = _Query(result=_result([]))
        client = _Client([lookup, insert, allocations])
        repository = SupabaseBudgetPlanRepository(client, USER)
        key = uuid4()

        repository.create(_plan(idempotency_key=key), [_allocation()])

        assert insert.inserted[0]["idempotency_key"] == str(key)

    def test_a_known_key_returns_the_stored_plan(self):
        lookup = _Query(result=_result([_stored_plan(id=42)]))
        groups = _Query(result=_result([]))
        client = _Client([lookup, groups])
        repository = SupabaseBudgetPlanRepository(client, USER)
        key = uuid4()

        stored = repository.create(_plan(idempotency_key=key), [_allocation()])

        assert stored.id == 42
        # Nothing was inserted: the lookup answered first.
        assert lookup.inserted == []
        assert groups.inserted == []

    def test_a_duplicate_race_returns_the_stored_plan(self):
        lookup = _Query(result=_result([]))
        insert = _Query(
            error=APIError({"code": "23505", "message": "duplicate key"})
        )
        race = _Query(result=_result([_stored_plan(id=42)]))
        groups = _Query(result=_result([]))
        client = _Client([lookup, insert, race, groups])
        repository = SupabaseBudgetPlanRepository(client, USER)
        key = uuid4()

        stored = repository.create(_plan(idempotency_key=key), [_allocation()])

        assert stored.id == 42
        assert insert.inserted[0]["idempotency_key"] == str(key)

    def test_a_plan_without_a_key_is_written_as_is(self):
        insert = _Query(result=_result([_stored_plan()]))
        allocations = _Query(result=_result([]))
        client = _Client([insert, allocations])
        repository = SupabaseBudgetPlanRepository(client, USER)

        repository.create(_plan(), [_allocation()])

        assert insert.inserted[0]["idempotency_key"] is None
