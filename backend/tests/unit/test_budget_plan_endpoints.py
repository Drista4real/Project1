"""HTTP-level tests for the budget plan endpoints.

The endpoints are exercised through the real FastAPI app with the
repository dependency replaced, so the routing, the response models and the
service wiring are covered without a live Supabase project.
"""

from datetime import date
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import UserContext, get_user_context
from app.api.v1.endpoints.budget_plans import (
    get_budget_plan_service,
    get_purchase_impact_service,
)
from app.domain.budget_plan import (
    BudgetPlan,
    DailyAllocation,
    PlanGroup,
)
from app.main import app


class FakeBudgetPlanRepository:
    """An in-memory plan store."""

    def __init__(self) -> None:
        self.plans = {
            1: BudgetPlan(
                id=1,
                title="Kế hoạch tháng",
                status="ACTIVE",
                total_income=Decimal("8000000"),
                duration_days=7,
                savings_target=Decimal("1000000"),
                fixed_expenses=Decimal("1400000"),
                start_date=date(2026, 11, 1),
                spendable_budget=Decimal("5600000"),
                daily_allowance=Decimal("800000"),
                survival_floor=Decimal("200000"),
                plan_version=1,
                config_version="budget-engine-v1",
                groups=(
                    PlanGroup(
                        group_key="food",
                        pillar="needs",
                        daily_amount=Decimal("480000"),
                        total_amount=Decimal("3360000"),
                    ),
                ),
            )
        }

    def get(self, plan_id: int) -> BudgetPlan:
        return self.plans[plan_id]

    def list_plans(self, active_only: bool, limit: int, offset: int) -> dict:
        items = list(self.plans.values())
        if active_only:
            items = [plan for plan in items if plan.status in {"ACTIVE", "REBALANCED"}]
        return {
            "items": items[offset : offset + limit],
            "total": len(items),
            "limit": limit,
            "offset": offset,
        }

    def allocations(self, plan_id: int) -> list[DailyAllocation]:
        return [
            DailyAllocation(
                day_index=1,
                alloc_date=date(2026, 11, 1),
                group_key="food",
                pillar="needs",
                amount=Decimal("480000"),
                actual_spent=Decimal("0"),
            )
        ]

    def events(self, plan_id: int) -> list:
        return []


@pytest.fixture
def client(monkeypatch):
    """A test client whose plan service uses the in-memory store."""
    from app.application.budget_plan import BudgetPlanService

    repository = FakeBudgetPlanRepository()
    service = BudgetPlanService(repository)

    async def fake_context():
        yield UserContext(client=None, user_id="user-1")

    app.dependency_overrides[get_user_context] = fake_context
    app.dependency_overrides[get_budget_plan_service] = lambda: service
    app.dependency_overrides[get_purchase_impact_service] = lambda: service
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


class TestBudgetPlanEndpoints:
    """The read endpoints of the deterministic budget engine."""

    def test_the_plans_are_listed(self, client):
        response = client.get("/api/v1/budget-plans")
        assert response.status_code == 200
        body = response.json()
        assert body["total"] == 1
        assert body["items"][0]["id"] == 1

    def test_the_pagination_window_is_honoured(self, client):
        response = client.get("/api/v1/budget-plans?limit=1&offset=1")
        assert response.status_code == 200
        assert response.json()["items"] == []

    def test_only_active_plans_are_listed(self, client):
        response = client.get("/api/v1/budget-plans?active=true")
        assert response.status_code == 200
        assert response.json()["total"] == 1

    def test_one_plan_is_returned(self, client):
        response = client.get("/api/v1/budget-plans/1")
        assert response.status_code == 200
        assert response.json()["plan"]["id"] == 1

    def test_the_allocations_of_a_plan_are_listed(self, client):
        response = client.get("/api/v1/budget-plans/1/allocations")
        assert response.status_code == 200
        assert response.json()["items"][0]["day_index"] == 1

    def test_the_events_of_a_plan_are_listed(self, client):
        response = client.get("/api/v1/budget-plans/1/events")
        assert response.status_code == 200
        assert response.json()["items"] == []
