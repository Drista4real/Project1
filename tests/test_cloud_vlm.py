"""Model 4 schema, arithmetic, persona, mock, and async SDK contract tests."""

import asyncio
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest
from app.application.use_cases.ingest_receipt import IngestReceipt
from app.domain.interfaces.advisor_interface import IFinancialAdvisor
from app.domain.interfaces.vlm_interface import IReceiptExtractor
from app.infrastructure.ai.cloud_vlm.advisor import PersonaFinancialAdvisor
from app.infrastructure.ai.cloud_vlm.client import (
    QwenVLMReceiptExtractor,
    check_receipt_arithmetic,
)
from app.infrastructure.ai.cloud_vlm.schemas import (
    AdvisorAlertResponse,
    ReceiptExtractionResult,
    ReceiptItemSchema,
    receipt_json_schema,
)
from google import genai
from pydantic import ValidationError


def receipt(**updates: object) -> ReceiptExtractionResult:
    """Create a valid extraction with optional overrides for each boundary test."""
    values = dict(
        merchant_name="Quán ăn",
        transaction_date="2026-10-12",
        items=[ReceiptItemSchema(name="Cơm", quantity=2, price=35_000)],
        total_amount=70_000,
        category="Ăn uống",
        confidence_score=0.1,
        is_arithmetic_valid=False,
    )
    values.update(updates)
    return ReceiptExtractionResult.model_validate(values)


@pytest.mark.parametrize(
    ("price", "total", "valid"),
    [
        (100, 100, True),
        (105, 100, True),
        (95, 100, True),
        (106, 100, False),
        (94, 100, False),
        (0, 0, True),
        (1, 0, False),
    ],
)
def test_arithmetic_tolerance(price: int, total: int, valid: bool) -> None:
    """Check exact-match and inclusive 5% bounds using integer arithmetic."""
    result = check_receipt_arithmetic(
        receipt(
            items=[ReceiptItemSchema(name="Món", price=price)],
            total_amount=total,
            is_arithmetic_valid=True,
            confidence_score=1.0,
        )
    )
    assert result.is_arithmetic_valid is valid
    assert result.confidence_score == (0.95 if valid else 0.60)


def test_quantity_and_missing_items() -> None:
    """Use quantity times unit price; unreadable line items always require review."""
    original = receipt()
    result = check_receipt_arithmetic(original)
    assert result.is_arithmetic_valid
    assert original.confidence_score == 0.1
    unreadable = check_receipt_arithmetic(receipt(items=[]))
    assert not unreadable.is_arithmetic_valid
    assert unreadable.confidence_score == 0.60
    assert not check_receipt_arithmetic(
        receipt(items=[], total_amount=0)
    ).is_arithmetic_valid


@pytest.mark.parametrize(
    "updates",
    [
        {"total_amount": -1},
        {"total_amount": "70000"},
        {"total_amount": True},
        {"confidence_score": 1.1},
        {"confidence_score": float("nan")},
        {"category": "food"},
        {"transaction_date": "2026-02-30"},
        {"transaction_date": "12/10/2026"},
        {"merchant_name": "  "},
        {"extra": 1},
    ],
)
def test_receipt_validation(updates: dict[str, object]) -> None:
    """Reject invalid date, money, category, confidence, and unexpected fields."""
    with pytest.raises(ValidationError):
        receipt(**updates)


@pytest.mark.parametrize(
    "updates", [{"quantity": 0}, {"quantity": True}, {"price": -1}, {"price": 1.5}]
)
def test_item_validation(updates: dict[str, object]) -> None:
    """Require integral nonnegative prices and positive integral quantities."""
    values = dict(name="Món", price=100)
    values.update(updates)
    with pytest.raises(ValidationError):
        ReceiptItemSchema.model_validate(values)


def test_advisor_schema_and_json_schema() -> None:
    """Validate allowed risk labels and expose the full receipt JSON schema."""
    assert ReceiptItemSchema(name="Món", price=100).quantity == 1
    with pytest.raises(ValidationError):
        AdvisorAlertResponse(alert_type="UNKNOWN", message="test")
    with pytest.raises(ValidationError):
        AdvisorAlertResponse(alert_type="SAFE", message=" ")
    assert "items" in receipt_json_schema()["properties"]
    assert receipt_json_schema()["additionalProperties"] is False


def test_default_test_and_missing_key_mock(monkeypatch: pytest.MonkeyPatch) -> None:
    """CI defaults to no network even if a key is accidentally present."""
    monkeypatch.setenv("GEMINI_API_KEY", "dummy-test-secret")
    constructor = Mock(side_effect=AssertionError("Network client must not be created"))
    monkeypatch.setattr(genai, "Client", constructor)
    extractor = QwenVLMReceiptExtractor()
    advisor = PersonaFinancialAdvisor()
    assert extractor.is_mock and advisor.is_mock
    assert IReceiptExtractor in type(extractor).__mro__
    assert IFinancialAdvisor in type(advisor).__mro__
    result = asyncio.run(extractor.extract_receipt(b"fixture"))
    assert result.is_arithmetic_valid and result.confidence_score == 0.95
    assert QwenVLMReceiptExtractor(api_key="", test_mode=False).is_mock
    assert PersonaFinancialAdvisor(api_key="", test_mode=False).is_mock
    constructor.assert_not_called()


def test_mock_domain_use_case_and_personas() -> None:
    """Keep receipt review fields across the domain boundary and both persona APIs."""
    extractor = QwenVLMReceiptExtractor(api_key="")
    result = asyncio.run(IngestReceipt(extractor).execute(b"fixture"))
    assert result.total == Decimal(35000)
    assert result.is_arithmetic_valid and result.confidence_score == 0.95
    assert result.items[0].price == 35000
    advisor = PersonaFinancialAdvisor(api_key="")
    fixed = asyncio.run(advisor.generate_fixed_income_alert(400_000, 4, [], True))
    flexible = asyncio.run(
        advisor.generate_flexible_income_alert(600_000, 6, 20_000, True)
    )
    safe_fixed = asyncio.run(
        advisor.generate_fixed_income_alert(2_000_000, 4, [], False)
    )
    safe_flexible = asyncio.run(
        advisor.generate_flexible_income_alert(2_000_000, None, 50_000, False)
    )
    assert fixed.alert_type == "CASHFLOW_MISMATCH"
    assert flexible.alert_type == "WINDFALL_DEPLETION"
    assert "20.000 VND/ngày" in flexible.message
    assert safe_fixed.alert_type == safe_flexible.alert_type == "SAFE"


@pytest.fixture
def sdk(monkeypatch: pytest.MonkeyPatch) -> tuple[Mock, AsyncMock]:
    """Replace the SDK constructor with an async client double; never call Google."""
    generate = AsyncMock()
    client = Mock()
    client.aio = SimpleNamespace(
        models=SimpleNamespace(generate_content=generate), aclose=AsyncMock()
    )
    constructor = Mock(return_value=client)
    monkeypatch.setattr(genai, "Client", constructor)
    return client, generate


def test_live_advisor_messages_and_safe_shortcut(sdk: tuple[Mock, AsyncMock]) -> None:
    """Call structured advice asynchronously, cap sentences, and keep SAFE local."""
    _client, generate = sdk
    advisor = PersonaFinancialAdvisor(api_key="dummy", test_mode=False)
    generate.return_value = SimpleNamespace(
        parsed=AdvisorAlertResponse(
            alert_type="CASHFLOW_MISMATCH",
            message="Hãy giãn mua sắm. Giảm ăn ngoài. Ưu tiên hóa đơn.",
            suggested_action="Hoãn mua sắm.",
        ),
        text=None,
    )
    fixed = asyncio.run(
        advisor.generate_fixed_income_alert(
            400_000, 3, [{"date": "2026-10-13", "balance": 300_000}], True
        )
    )
    assert fixed.message == "Hãy giãn mua sắm. Giảm ăn ngoài."
    assert generate.call_args.kwargs["model"] == "gemini-2.5-flash"
    assert generate.call_args.kwargs["config"].response_schema is None
    assert (
        generate.call_args.kwargs["config"].response_json_schema
        == AdvisorAlertResponse.model_json_schema()
    )
    assert "TUYỆT ĐỐI không tính toán" in generate.call_args.kwargs["contents"]
    generate.return_value = SimpleNamespace(
        parsed=AdvisorAlertResponse(
            alert_type="WINDFALL_DEPLETION",
            message="Hãy giảm chi tiêu. Hoãn mua sắm.",
        ),
        text=None,
    )
    flexible = asyncio.run(
        advisor.generate_flexible_income_alert(600_000, 6, 20_000, True)
    )
    assert (
        flexible.message
        == "Hãy giảm chi tiêu. Hạn mức chi tiêu an toàn đã tính là 20.000 VND/ngày."
    )
    calls = generate.call_count
    assert (
        asyncio.run(
            advisor.generate_fixed_income_alert(4_000_000, 4, [], False)
        ).alert_type
        == "SAFE"
    )
    assert (
        asyncio.run(
            advisor.generate_flexible_income_alert(4_000_000, None, 100_000, False)
        ).alert_type
        == "SAFE"
    )
    assert generate.call_count == calls


def test_advisor_rejects_numeric_claims_and_wrong_alerts(
    sdk: tuple[Mock, AsyncMock],
) -> None:
    """The LLM cannot invent a daily limit or override Model 2's flag."""
    _client, generate = sdk
    advisor = PersonaFinancialAdvisor(api_key="dummy", test_mode=False)
    for kind, message in [
        ("SAFE", "Bạn an toàn."),
        ("WINDFALL_DEPLETION", "Hãy chi 999999 đồng mỗi ngày."),
    ]:
        generate.return_value = SimpleNamespace(
            parsed=AdvisorAlertResponse(alert_type=kind, message=message), text=None
        )
        result = asyncio.run(
            advisor.generate_flexible_income_alert(600_000, 6, 20_000, True)
        )
        assert result.alert_type == "WINDFALL_DEPLETION"
        assert "20.000 VND/ngày" in result.message
        assert "999999" not in result.message
    generate.side_effect = TimeoutError("offline")
    assert (
        asyncio.run(advisor.generate_fixed_income_alert(1000, 5, [], True)).alert_type
        == "CASHFLOW_MISMATCH"
    )


@pytest.mark.parametrize("mime", ["text/plain", "application/pdf"])
def test_image_validation(mime: str) -> None:
    """Validate even mock inputs to keep the real and mock contracts consistent."""
    extractor = QwenVLMReceiptExtractor(api_key="")
    with pytest.raises(ValueError):
        asyncio.run(extractor.extract_receipt(b"image", mime))
    with pytest.raises(ValueError):
        asyncio.run(extractor.extract_receipt(b""))


@pytest.mark.parametrize("timeout", [0, -1, float("inf"), float("nan")])
def test_timeout_configuration(timeout: float) -> None:
    """Reject invalid deadlines before allocating SDK resources."""
    with pytest.raises(ValueError):
        QwenVLMReceiptExtractor(timeout_seconds=timeout)


def test_advisor_invalid_metrics() -> None:
    """NaN metrics and invalid flags cannot enter cloud prompts or local messages."""
    advisor = PersonaFinancialAdvisor(api_key="")
    with pytest.raises(ValueError):
        asyncio.run(advisor.generate_fixed_income_alert(float("nan"), 3, [], True))
    with pytest.raises(ValueError):
        asyncio.run(advisor.generate_fixed_income_alert(1000, -1, [], True))
    with pytest.raises(ValueError):
        asyncio.run(advisor.generate_flexible_income_alert(1000, -1, 10, True))


def test_advisor_never_uses_openrouter_key(monkeypatch: pytest.MonkeyPatch) -> None:
    """A Qwen credential cannot enable the Gemini financial advisor."""
    monkeypatch.setenv("GEMINI_API_KEY", "")
    monkeypatch.setenv("OPENROUTER_API_KEY", "openrouter-test-key")
    constructor = Mock(side_effect=AssertionError("Gemini must remain offline"))
    monkeypatch.setattr(genai, "Client", constructor)
    assert PersonaFinancialAdvisor(test_mode=False).is_mock
    constructor.assert_not_called()


def test_local_key_configuration(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Use ignored dotenv files with explicit environment precedence."""
    from app.infrastructure.ai.cloud_vlm import _gemini

    monkeypatch.setattr(_gemini, "PROJECT_ROOT", tmp_path)
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    (tmp_path / "backend").mkdir()
    (tmp_path / "backend/.env").write_text(
        "GEMINI_API_KEY='local-test-key'\n", encoding="utf-8"
    )
    assert _gemini.configured_api_key() == "local-test-key"
    monkeypatch.setenv("GEMINI_API_KEY", "environment-test-key")
    assert _gemini.configured_api_key() == "environment-test-key"
    monkeypatch.setenv("GEMINI_API_KEY", "")
    assert _gemini.configured_api_key() == ""
