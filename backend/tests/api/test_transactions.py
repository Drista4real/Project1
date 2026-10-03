import json
from dataclasses import replace

import httpx
import pytest
from fastapi.testclient import TestClient
from supabase import create_client

from app.api import dependencies
from app.infrastructure.config.settings import Settings
from app.main import app

USER = "11111111-1111-4111-8111-111111111111"
OTHER_USER = "22222222-2222-4222-8222-222222222222"
DATE = "2026-10-03T00:00:00+00:00"


@pytest.fixture
def api(monkeypatch):
    records = {}
    requests = []
    transports = []

    def handle(request):
        requests.append(request)
        if request.url.path == "/auth/v1/user":
            if request.headers["authorization"] != "Bearer valid-token":
                return httpx.Response(401, json={"msg": "Invalid JWT"})
            return httpx.Response(
                200,
                json={
                    "id": USER,
                    "aud": "authenticated",
                    "role": "authenticated",
                    "email": "test@example.com",
                    "created_at": DATE,
                    "app_metadata": {},
                    "user_metadata": {},
                },
            )
        assert request.headers["authorization"] == "Bearer valid-token"
        path = request.url.path
        if path.endswith("/profiles"):
            assert request.url.params["id"] == f"eq.{USER}"
            return httpx.Response(200, json=[{"current_balance": "25000.00"}])
        if path.endswith("/accounts"):
            assert request.url.params["user_id"] == f"eq.{USER}"
            rows = [
                {
                    "id": 1,
                    "name": "Cash",
                    "balance": "100.00",
                    "currency": "VND",
                    "is_archived": False,
                },
                {
                    "id": 2,
                    "name": "Bank",
                    "balance": "200.00",
                    "currency": "VND",
                    "is_archived": False,
                },
            ]
            if "id" in request.url.params:
                rows = [
                    row for row in rows if request.url.params["id"] == f"eq.{row['id']}"
                ]
            return httpx.Response(200, json=rows)
        if path.endswith("/categories"):
            assert USER in request.url.params["or"]
            rows = [
                {
                    "id": 1,
                    "name": "Food",
                    "icon": "restaurant",
                    "color": "#10B981",
                    "is_income": False,
                    "pillar": "needs",
                }
            ]
            if "id" in request.url.params:
                rows = [
                    row for row in rows if request.url.params["id"] == f"eq.{row['id']}"
                ]
            return httpx.Response(200, json=rows)
        assert path.endswith("/transactions")
        if request.method == "POST":
            payload = json.loads(request.content)
            assert payload["user_id"] == USER
            row = {
                **payload,
                "id": 1,
                "created_at": DATE,
                "updated_at": DATE,
                "categories": {"name": "Ăn uống"},
            }
            records[1] = row
            return httpx.Response(201, json=[row])
        assert request.url.params["user_id"] == f"eq.{USER}"
        rows = [row for row in records.values() if row["user_id"] == USER]
        if "id" in request.url.params:
            rows = [
                row for row in rows if f"eq.{row['id']}" == request.url.params["id"]
            ]
        if request.method == "PATCH":
            rows = [
                row
                for row in rows
                if request.url.params["updated_at"] == f"eq.{row['updated_at']}"
            ]
            for row in rows:
                row.update(json.loads(request.content))
        if request.method == "DELETE":
            for row in rows:
                records.pop(row["id"])
        if "transaction_type" in request.url.params:
            rows = [
                row
                for row in rows
                if request.url.params["transaction_type"]
                == f"eq.{row['transaction_type']}"
            ]
        total = len(rows)
        offset = int(request.url.params.get("offset", 0))
        limit = int(request.url.params.get("limit", 1000))
        return httpx.Response(
            200,
            json=rows[offset : offset + limit],
            headers={"content-range": f"0-0/{total}"},
        )

    def factory(url, key, options):
        transport = httpx.Client(transport=httpx.MockTransport(handle))
        transports.append(transport)
        return create_client(
            url,
            key,
            replace(
                options,
                httpx_client=transport,
            ),
        )

    monkeypatch.setattr(dependencies, "create_client", factory)
    monkeypatch.setattr(
        dependencies,
        "get_settings",
        lambda: Settings(
            _env_file=None,
            supabase_url="https://example.supabase.co",
            supabase_publishable_key="sb_publishable_example",
        ),
    )
    with TestClient(app, headers={"Authorization": "Bearer valid-token"}) as client:
        yield client, records, requests
    for transport in transports:
        transport.close()


def payload(**changes):
    return {
        "amount": "45000.00",
        "transaction_type": "expense",
        "account_id": 1,
        "category_id": 1,
        "raw_description": "Cà phê",
        **changes,
    }


def test_full_crud(api):
    client, records, _ = api
    created = client.post("/api/v1/transactions", json=payload())
    assert created.status_code == 201, created.text
    assert created.json()["amount"] == "45000.00"
    page = client.get("/api/v1/transactions?limit=10&offset=0")
    assert page.status_code == 200
    assert page.json()["total"] == 1
    assert client.get("/api/v1/transactions/1").json()["raw_description"] == "Cà phê"
    updated = client.patch(
        "/api/v1/transactions/1", json={"amount": "55000.00", "category_id": None}
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["amount"] == "55000.00"
    assert updated.json()["raw_description"] == "Cà phê"
    assert updated.json()["category_id"] is None
    deleted = client.delete("/api/v1/transactions/1")
    assert deleted.status_code == 204
    assert deleted.content == b""
    assert not records
    assert client.get("/api/v1/transactions/1").status_code == 404


@pytest.mark.parametrize(
    "changes",
    [
        {"amount": "0"},
        {"amount": "-1"},
        {"amount": "1.001"},
        {"amount": "10000000000000"},
        {"user_id": OTHER_USER},
        {"transaction_type": "wrong"},
        {"transaction_date": "2026-10-03T10:00:00"},
        {"transaction_type": "transfer", "to_account_id": 1},
        {"account_id": 999},
        {"category_id": 999},
        {"transaction_type": "income"},
    ],
)
def test_invalid_create(api, changes):
    client, records, _ = api
    assert (
        client.post("/api/v1/transactions", json=payload(**changes)).status_code == 422
    )
    assert not records


@pytest.mark.parametrize(
    "changes",
    [
        {},
        {"amount": None},
        {"transaction_type": None},
        {"id": 4},
        {"transaction_type": "transfer"},
    ],
)
def test_invalid_patch(api, changes):
    client, _, _ = api
    assert client.post("/api/v1/transactions", json=payload()).status_code == 201
    assert client.patch("/api/v1/transactions/1", json=changes).status_code == 422


@pytest.mark.parametrize("method", ["get", "patch", "delete"])
def test_other_users_record_is_hidden(api, method):
    client, records, _ = api
    records[7] = {"id": 7, "user_id": OTHER_USER}
    kwargs = {"json": {"amount": "20.00"}} if method == "patch" else {}
    assert (
        getattr(client, method)("/api/v1/transactions/7", **kwargs).status_code == 404
    )
    assert 7 in records


def test_invalid_token_never_queries_data(api):
    client, _, requests = api
    response = client.get(
        "/api/v1/transactions", headers={"Authorization": "Bearer invalid-token"}
    )
    assert response.status_code == 401
    assert all(request.url.path == "/auth/v1/user" for request in requests)


def test_missing_token(client):
    assert client.get("/api/v1/transactions").status_code == 401


@pytest.mark.parametrize("query", ["limit=101", "limit=0", "offset=-1"])
def test_pagination_limits(api, query):
    assert api[0].get(f"/api/v1/transactions?{query}").status_code == 422


def test_transfer_and_finance_lookups(api):
    client, _, _ = api
    response = client.post(
        "/api/v1/transactions",
        json=payload(
            transaction_type="transfer",
            to_account_id=2,
            category_id=None,
        ),
    )
    assert response.status_code == 201, response.text
    assert client.get("/api/v1/accounts").json()[0]["name"] == "Cash"
    assert client.get("/api/v1/categories").json()[0]["name"] == "Food"
    overview = client.get("/api/v1/overview")
    assert overview.status_code == 200, overview.text
    assert overview.json() == {
        "current_balance": "25000.00",
        "monthly_income": "0",
        "monthly_expense": "0",
    }


def test_list_pagination_and_filters(api):
    client, records, _ = api
    assert client.post("/api/v1/transactions", json=payload()).status_code == 201
    records[2] = {**records[1], "id": 2}
    records[3] = {**records[1], "id": 3, "transaction_type": "income"}
    records[4] = {**records[1], "id": 4, "user_id": OTHER_USER}
    page = client.get("/api/v1/transactions?limit=1&offset=1&transaction_type=expense")
    assert page.status_code == 200, page.text
    assert page.json()["total"] == 2
    assert [row["id"] for row in page.json()["items"]] == [2]


def test_concurrent_update_is_rejected(api, monkeypatch):
    from app.infrastructure.repositories.transactions import (
        SupabaseTransactionRepository,
    )

    client, records, _ = api
    assert client.post("/api/v1/transactions", json=payload()).status_code == 201
    original = SupabaseTransactionRepository.get

    def concurrent_get(repository, transaction_id):
        current = original(repository, transaction_id)
        records[1]["updated_at"] = "2026-10-03T00:00:01+00:00"
        return current

    monkeypatch.setattr(SupabaseTransactionRepository, "get", concurrent_get)
    response = client.patch("/api/v1/transactions/1", json={"amount": "20.00"})
    assert response.status_code == 409
    assert records[1]["amount"] == "45000.00"
