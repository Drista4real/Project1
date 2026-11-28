"""The forecast route is registered and reports unavailability honestly.

Model 2 forecasts from the user's own daily balance history, which the backend
does not read yet. The route therefore exists but has no forecaster installed,
so it must answer 503 with an actionable message and never an estimate.
"""

from datetime import date
from decimal import Decimal
from unittest.mock import Mock

import pytest
from fastapi.testclient import TestClient

from app.api.v1.forecast import (
    FORECAST_UNAVAILABLE,
    INVALID_HISTORY,
    get_cashflow_forecaster,
)
from app.application.use_cases.cashflow_forecast import ForecastCashflow
from app.domain.interfaces.forecaster_interface import (
    BalancePoint,
    CashflowForecast,
)
from app.main import app


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def installed_forecaster():
    """Install a forecaster the way the composition root would.

    FastAPI captures the dependency callable when the route is registered, so
    the override goes through the app's dependency registry.
    """
    try:
        yield lambda use_case: app.dependency_overrides.__setitem__(
            get_cashflow_forecaster, lambda: use_case
        )
    finally:
        app.dependency_overrides.pop(get_cashflow_forecaster, None)


@pytest.fixture
def history() -> list[dict]:
    """Eight consecutive daily balances, the minimum Model 2 needs."""
    return [
        {"day": f"2026-01-{day:02d}", "balance": "8000000.00"}
        for day in range(1, 9)
    ]


class TestForecastRoute:
    """Registration, unavailability and input validation."""

    def test_the_route_is_registered(self, client):
        """The route is reachable under the shared prefix convention."""
        paths = client.get("/openapi.json").json()["paths"]
        assert "/api/v1/forecast" in paths
        assert "post" in paths["/api/v1/forecast"]

    def test_no_path_repeats_the_api_prefix(self, client):
        """Every router keeps its own full prefix; none is doubled."""
        paths = client.get("/openapi.json").json()["paths"]
        assert not [path for path in paths if "/api/v1/api/v1" in path]

    def test_an_unconfigured_forecaster_reports_unavailable(self, client, history):
        """Without a forecaster the route says so instead of estimating."""
        response = client.post(
            "/api/v1/forecast",
            json={"history": history, "income_type": "fixed"},
        )
        assert response.status_code == 503
        assert response.json()["detail"] == FORECAST_UNAVAILABLE

    def test_an_unconfigured_forecaster_reports_no_forecast(self, client, history):
        """A 503 body carries no balance, runway or alert numbers."""
        body = client.post(
            "/api/v1/forecast",
            json={"history": history, "income_type": "fixed"},
        ).json()
        assert set(body) == {"detail"}

    def test_no_forecaster_is_installed_by_default(self):
        """The composition root owns the wiring; nothing is installed yet."""
        assert get_cashflow_forecaster() is None

    @pytest.mark.parametrize(
        "body",
        [
            {"history": [], "income_type": "fixed"},
            {"history": [{"day": "2026-01-01", "balance": "1"}], "income_type": "x"},
            {"history": [{"day": "nope", "balance": "1"}], "income_type": "fixed"},
            {"income_type": "fixed"},
        ],
    )
    def test_an_invalid_request_is_rejected(self, client, body):
        """Malformed input never reaches the forecaster."""
        assert client.post("/api/v1/forecast", json=body).status_code == 422

    def test_the_history_length_is_bounded(self, client):
        """A series longer than a year of daily points is refused."""
        history = [
            {"day": f"2026-01-{day:02d}", "balance": "1"} for day in range(1, 29)
        ] * 20
        assert (
            client.post(
                "/api/v1/forecast", json={"history": history, "income_type": "fixed"}
            ).status_code
            == 422
        )


class TestForecastWithAForecaster:
    """The route forwards to Model 2 and maps its failures honestly."""

    def test_the_forecast_is_returned(self, client, installed_forecaster, history):
        """A configured forecaster produces the forecast the use case returns."""
        expected = CashflowForecast(
            balances=(
                BalancePoint(day=date(2026, 1, 9), balance=Decimal("7900000.00")),
            ),
            runway_days=30.0,
            alert_flag=False,
        )
        use_case = Mock(spec=ForecastCashflow)
        use_case.execute.return_value = expected
        installed_forecaster(use_case)
        response = client.post(
            "/api/v1/forecast",
            json={"history": history, "income_type": "fixed", "horizon_days": 30},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["balances"][0]["day"] == "2026-01-09"
        assert body["balances"][0]["balance"] == "7900000.00"
        assert body["runway_days"] == 30.0
        assert body["alert_flag"] is False
        use_case.execute.assert_called_once()

    def test_an_invalid_series_is_reported_as_bad_request(
        self, client, installed_forecaster
    ):
        """Model 2's input rules surface as 422, never as a fabricated answer."""
        use_case = Mock(spec=ForecastCashflow)
        use_case.execute.side_effect = ValueError("history too short")
        installed_forecaster(use_case)
        response = client.post(
            "/api/v1/forecast",
            json={
                "history": [{"day": "2026-01-01", "balance": "8000000.00"}],
                "income_type": "fixed",
            },
        )
        assert response.status_code == 422
        assert response.json()["detail"] == INVALID_HISTORY
