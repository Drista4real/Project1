"""Receipt uploads are bounded, authenticated, unpersisted, and honest on failure."""

import io
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.api.dependencies import UserContext, get_user_context
from app.api.v1 import ingestion as routes
from app.application.use_cases.ingest_receipt import IngestReceipt
from app.domain.interfaces.vlm_interface import ReceiptData, ReceiptItem
from app.infrastructure.ai.cloud_vlm._common import CloudVLMError
from app.main import app


def image_bytes(fmt="PNG", size=(12, 12)):
    output = io.BytesIO()
    Image.new("RGB", size, "white").save(output, format=fmt)
    return output.getvalue()


@pytest.fixture
def receipts():
    extractor = SimpleNamespace(
        extract=AsyncMock(
            return_value=ReceiptData(
                merchant="Quán ăn",
                total=Decimal("100000"),
                issued_on=date(2026, 11, 10),
                items=(ReceiptItem("Cơm", 2, 50000),),
                category="Ăn uống",
                confidence_score=0.95,
                is_arithmetic_valid=True,
            )
        )
    )
    # No database methods exist: an accidental write must fail this test.
    app.dependency_overrides[get_user_context] = lambda: UserContext(
        client=SimpleNamespace(), user_id="test-user"
    )
    app.dependency_overrides[routes.get_receipt_ingestor] = lambda: IngestReceipt(
        extractor
    )
    try:
        yield TestClient(app), extractor
    finally:
        app.dependency_overrides.pop(get_user_context, None)
        app.dependency_overrides.pop(routes.get_receipt_ingestor, None)


@pytest.mark.parametrize(
    ("fmt", "mime"),
    [("PNG", "image/png"), ("JPEG", "image/jpeg"), ("WEBP", "image/webp")],
)
def test_receipt_returns_one_draft_with_printed_total_and_date(receipts, fmt, mime):
    api, extractor = receipts
    data = image_bytes(fmt)
    result = api.post(
        "/api/v1/ingestion/receipt", content=data, headers={"Content-Type": mime}
    )
    assert result.status_code == 200
    (draft,) = result.json()["drafts"]
    assert draft["amount"] == 100000
    assert draft["transaction_type"] == "expense"
    assert draft["occurred_on"] == "2026-11-10"
    assert draft["source"] == "QWEN"
    assert draft["category"] == "Ăn uống"
    assert draft["confidence"] == 0  # Do not present arithmetic as confidence.
    assert draft["warnings"]
    extractor.extract.assert_awaited_once_with(data, mime)


@pytest.mark.parametrize(
    ("data", "mime", "status"),
    [
        (b"", "image/png", 422),
        (b"not an image", "image/png", 422),
        (b"%PDF-1.4", "application/pdf", 415),
        (image_bytes(), "image/jpeg", 422),
        (image_bytes()[:30], "image/png", 422),
    ],
)
def test_invalid_uploads_never_call_provider(receipts, data, mime, status):
    api, extractor = receipts
    result = api.post(
        "/api/v1/ingestion/receipt", content=data, headers={"Content-Type": mime}
    )
    assert result.status_code == status
    extractor.extract.assert_not_awaited()


def test_size_limit_covers_chunked_uploads_without_content_length(
    receipts, monkeypatch
):
    api, extractor = receipts
    monkeypatch.setattr(routes, "MAX_RECEIPT_BYTES", 64)
    for data in (b"x" * 65, iter([b"x" * 32, b"y" * 33])):
        response = api.post(
            "/api/v1/ingestion/receipt",
            content=data,
            headers={"Content-Type": "image/png"},
        )
        assert response.status_code == 413
    extractor.extract.assert_not_awaited()


def test_pixel_limit_rejects_compressed_large_image(receipts, monkeypatch):
    api, extractor = receipts
    monkeypatch.setattr(routes, "MAX_RECEIPT_PIXELS", 100)
    response = api.post(
        "/api/v1/ingestion/receipt",
        content=image_bytes(),
        headers={"Content-Type": "image/png"},
    )
    assert response.status_code == 422
    extractor.extract.assert_not_awaited()


@pytest.mark.parametrize("reason", ["timeout", "quota", "validation", "auth"])
def test_provider_errors_are_safe_and_never_mock_success(receipts, reason):
    api, extractor = receipts
    extractor.extract.side_effect = CloudVLMError(
        "private upstream info", reason=reason
    )
    response = api.post(
        "/api/v1/ingestion/receipt",
        content=image_bytes(),
        headers={"Content-Type": "image/png"},
    )
    assert response.status_code == 503
    assert "private" not in response.text
    assert "drafts" not in response.json()


def test_mismatched_arithmetic_preserves_total_with_warning(receipts):
    api, extractor = receipts
    extractor.extract.return_value = ReceiptData(
        merchant=None,
        total=Decimal("110000"),
        items=(ReceiptItem("Món ăn", 1, 100000),),
        is_arithmetic_valid=False,
    )
    response = api.post(
        "/api/v1/ingestion/receipt",
        content=image_bytes(),
        headers={"Content-Type": "image/png"},
    )
    draft = response.json()["drafts"][0]
    assert draft["amount"] == 110000
    assert draft["occurred_on"] is None
    assert len(draft["warnings"]) == 3


@pytest.mark.parametrize("total", ["0", "-1", "100.5", "10000000000000", "NaN"])
def test_invalid_totals_are_not_coerced_or_saved(receipts, total):
    api, extractor = receipts
    extractor.extract.return_value = ReceiptData(merchant=None, total=Decimal(total))
    response = api.post(
        "/api/v1/ingestion/receipt",
        content=image_bytes(),
        headers={"Content-Type": "image/png"},
    )
    assert response.status_code == 422


def test_authentication_required_before_extraction(receipts):
    api, extractor = receipts
    app.dependency_overrides.pop(get_user_context)
    response = api.post(
        "/api/v1/ingestion/receipt",
        content=image_bytes(),
        headers={"Content-Type": "image/png"},
    )
    assert response.status_code == 401
    extractor.extract.assert_not_awaited()


def test_unconfigured_extractor_is_rejected(receipts, monkeypatch):
    api, _ = receipts
    app.dependency_overrides.pop(routes.get_receipt_ingestor)
    monkeypatch.setattr(
        app.state, "receipt_extractor", SimpleNamespace(is_mock=True), raising=False
    )
    response = api.post(
        "/api/v1/ingestion/receipt",
        content=image_bytes(),
        headers={"Content-Type": "image/png"},
    )
    assert response.status_code == 503
