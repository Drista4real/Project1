"""Tests for setting the single available balance the app shows.

The app shows one balance: the sum of the wallets included in the total.
Setting it adjusts the primary wallet so that sum equals the amount, without
recording a ledger transaction (ADR 0006: a balance edit is not income).
"""

from decimal import Decimal
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import UserContext, get_finance_service, get_user_context
from app.application.finance import FinanceService
from app.infrastructure.repositories.finance import SupabaseFinanceQueries
from app.main import app


class _FakeQueries:
    def __init__(self, wallets):
        self.wallets = wallets
        self.updates: list[tuple[int, Decimal]] = []
        self.created: list[Decimal] = []

    def included_wallets(self) -> list[dict]:
        return self.wallets

    def set_wallet_balance(self, wallet_id: int, balance: Decimal) -> None:
        self.updates.append((wallet_id, balance))

    def create_wallet(self, balance: Decimal) -> None:
        self.created.append(balance)


class TestSetBalance:
    def test_the_only_wallet_takes_the_amount(self):
        queries = _FakeQueries([{"id": 4, "balance": "0.00", "is_archived": False}])
        result = FinanceService(queries).set_balance(Decimal("5000000"))
        assert queries.updates == [(4, Decimal("5000000"))]
        assert queries.created == []
        assert result == {"current_balance": "5000000"}

    def test_other_included_wallets_keep_the_total_equal_to_the_amount(self):
        queries = _FakeQueries(
            [
                {"id": 4, "balance": "100000.00", "is_archived": False},
                {"id": 9, "balance": "1500000.00", "is_archived": False},
                {"id": 2, "balance": "200000.00", "is_archived": True},
            ]
        )
        FinanceService(queries).set_balance(Decimal("5000000"))
        assert queries.updates == [(4, Decimal("3300000.00"))]

    def test_an_archived_wallet_is_never_the_primary_one(self):
        queries = _FakeQueries(
            [
                {"id": 1, "balance": "50000.00", "is_archived": True},
                {"id": 7, "balance": "0.00", "is_archived": False},
            ]
        )
        FinanceService(queries).set_balance(Decimal("1000000"))
        assert queries.updates == [(7, Decimal("950000.00"))]

    def test_without_a_usable_wallet_a_cash_wallet_is_created(self):
        queries = _FakeQueries([{"id": 1, "balance": "0.00", "is_archived": True}])
        FinanceService(queries).set_balance(Decimal("2000000"))
        assert queries.updates == []
        assert queries.created == [Decimal("2000000")]


class _Query:
    def __init__(self, data=None):
        self.data = data if data is not None else []
        self.filters: list[tuple] = []
        self.updated: dict | None = None
        self.inserted: dict | None = None

    def select(self, *args, **kwargs):
        return self

    def eq(self, column, value):
        self.filters.append((column, value))
        return self

    def order(self, *args, **kwargs):
        return self

    def update(self, payload):
        self.updated = payload
        return self

    def insert(self, payload):
        self.inserted = payload
        return self

    def execute(self):
        return SimpleNamespace(data=self.data)


class _Client:
    def __init__(self, data=None):
        self.data = data or []
        self.queries: list[_Query] = []

    def table(self, name):
        assert name == "accounts"
        query = _Query(self.data)
        self.queries.append(query)
        return query


USER = "11111111-1111-4111-8111-111111111111"


class TestBalanceQueries:
    def test_included_wallets_are_read_for_the_owner(self):
        client = _Client([{"id": 1}])
        assert SupabaseFinanceQueries(client, USER).included_wallets() == [{"id": 1}]
        filters = client.queries[0].filters
        assert ("user_id", USER) in filters
        assert ("is_included_in_total", True) in filters

    def test_a_wallet_balance_is_written_for_the_owner_only(self):
        client = _Client()
        SupabaseFinanceQueries(client, USER).set_wallet_balance(4, Decimal("12.50"))
        query = client.queries[0]
        assert query.updated == {"balance": "12.50"}
        assert ("id", 4) in query.filters
        assert ("user_id", USER) in query.filters

    def test_a_created_wallet_belongs_to_the_owner(self):
        client = _Client()
        SupabaseFinanceQueries(client, USER).create_wallet(Decimal("2000000"))
        inserted = client.queries[0].inserted
        assert inserted["user_id"] == USER
        assert inserted["account_type"] == "cash"
        assert inserted["balance"] == "2000000"


@pytest.fixture
def client_with():
    queries = _FakeQueries([{"id": 4, "balance": "0.00", "is_archived": False}])

    async def fake_context():
        yield UserContext(client=None, user_id="user-1")

    app.dependency_overrides[get_user_context] = fake_context
    app.dependency_overrides[get_finance_service] = lambda: FinanceService(queries)
    with TestClient(app) as test_client:
        yield test_client, queries
    app.dependency_overrides.clear()


class TestBalanceEndpoint:
    def test_the_balance_is_set(self, client_with):
        client, queries = client_with
        response = client.put("/api/v1/balance", json={"amount": "5000000.00"})
        assert response.status_code == 200
        assert response.json() == {"current_balance": "5000000.00"}
        assert queries.updates == [(4, Decimal("5000000.00"))]

    def test_a_negative_balance_is_refused(self, client_with):
        client, queries = client_with
        response = client.put("/api/v1/balance", json={"amount": "-1"})
        assert response.status_code == 422
        assert queries.updates == []

    def test_the_balance_needs_a_signed_in_user(self):
        with TestClient(app) as anonymous:
            response = anonymous.put("/api/v1/balance", json={"amount": "1"})
        assert response.status_code == 401
