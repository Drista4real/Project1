"""Exercise local readiness and receipt pool ownership at application startup."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest
from fastapi.testclient import TestClient

from app import main


@pytest.mark.parametrize("status", ["ready", "unavailable"])
def test_startup_warms_once_and_closes_receipt_pool(monkeypatch, status) -> None:
    """Optional classifier failure preserves CRUD liveness and closes resources."""
    warmup = Mock(return_value={"status": status, "load_ms": 10, "warmup_ms": 2})
    extractor = SimpleNamespace(aclose=AsyncMock())
    monkeypatch.setattr(
        main, "get_settings", lambda: SimpleNamespace(classifier_warmup=True)
    )
    monkeypatch.setattr(main, "warmup_classifier", warmup)
    monkeypatch.setattr(main, "QwenVLMReceiptExtractor", lambda: extractor)
    with TestClient(main.app) as client:
        assert client.get("/health").status_code == 200
        response = client.get("/ready/ai")
        assert response.status_code == (200 if status == "ready" else 503)
        assert response.json()["status"] == status
        assert main.app.state.receipt_extractor is extractor
        extractor.aclose.assert_not_awaited()
    warmup.assert_called_once()
    extractor.aclose.assert_awaited_once()


def test_disabled_warmup_does_not_load_model(monkeypatch) -> None:
    """A CRUD-only deployment can keep the ML runtime lazy."""
    warmup = Mock()
    monkeypatch.setattr(
        main, "get_settings", lambda: SimpleNamespace(classifier_warmup=False)
    )
    monkeypatch.setattr(main, "warmup_classifier", warmup)
    with TestClient(main.app) as client:
        assert client.get("/health").status_code == 200
        assert client.get("/ready/ai").json()["status"] == "not_warmed"
    warmup.assert_not_called()


def test_bad_receipt_configuration_preserves_liveness(monkeypatch) -> None:
    """An optional provider misconfiguration must not stop finance endpoints."""
    monkeypatch.setattr(
        main, "get_settings", lambda: SimpleNamespace(classifier_warmup=False)
    )
    monkeypatch.setattr(
        main, "QwenVLMReceiptExtractor", Mock(side_effect=ValueError("invalid URL"))
    )
    with TestClient(main.app) as client:
        assert client.get("/health").status_code == 200
        assert main.app.state.receipt_extractor is None
