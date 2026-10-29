"""Qwen transport tests are isolated from Gemini SDK and live credentials."""

import asyncio
import base64
import json
from unittest.mock import AsyncMock, Mock

import httpx
import pytest
from app.infrastructure.ai.cloud_vlm._common import CloudVLMError
from app.infrastructure.ai.cloud_vlm.client import DocumentVLMClient
from app.infrastructure.ai.cloud_vlm.qwen_client import (
    QwenVLMReceiptExtractor,
    parse_receipt_content,
)


def receipt_json() -> str:
    """Return a schema-valid receipt with deliberately false model arithmetic."""
    return json.dumps(
        {
            "merchant_name": "Shop",
            "transaction_date": None,
            "items": [{"name": "Lunch", "quantity": 2, "price": 35000}],
            "total_amount": 70000,
            "category": "Ăn uống",
            "confidence_score": 0.1,
            "is_arithmetic_valid": False,
        }
    )


@pytest.mark.parametrize(
    "day", ["12/10/2026", "12-10-2026", "12.10.2026", " 12/10/2026 ", "2026-10-12"]
)
@pytest.mark.parametrize("fenced", [False, True])
def test_receipt_date_normalization(day: str, fenced: bool) -> None:
    """Preserve receipt dates while normalizing Vietnamese notation and fences."""
    values = json.loads(receipt_json())
    values["transaction_date"] = day
    content = json.dumps(values)
    if fenced:
        content = f"```json\n{content}\n```"
    result = parse_receipt_content(content)
    assert result.transaction_date == "2026-10-12"
    assert result.total_amount == values["total_amount"]
    assert result.items[0].price == values["items"][0]["price"]


@pytest.mark.parametrize("day", ["31/02/2026", "12/10/26", "10/31/2026", "2026-02-30"])
def test_invalid_receipt_dates_remain_rejected(day: str) -> None:
    """Do not invent dates or guess foreign notation or two-digit years."""
    values = json.loads(receipt_json())
    values["transaction_date"] = day
    with pytest.raises(ValueError):
        parse_receipt_content(json.dumps(values))


def test_wrappers_do_not_relax_schema() -> None:
    """Fences cannot bypass strict money types, categories or extra-field rules."""
    for updates in ({"total_amount": "70000"}, {"extra": 1}, {"category": "food"}):
        values = json.loads(receipt_json())
        values.update(updates)
        with pytest.raises(ValueError):
            parse_receipt_content(f"```json\n{json.dumps(values)}\n```")


@pytest.fixture
def transport(monkeypatch: pytest.MonkeyPatch) -> Mock:
    """Replace async HTTP requests so explicit live mode remains offline."""
    monkeypatch.setenv("QWEN_MODEL", "qwen/qwen-2.5-vl-7b-instruct")
    monkeypatch.setenv("QWEN_BASE_URL", "https://openrouter.ai/api/v1")
    client = Mock(post=AsyncMock(), aclose=AsyncMock())
    monkeypatch.setattr(httpx, "AsyncClient", Mock(return_value=client))
    return client


def test_multimodal_request_and_lifecycle(transport: Mock) -> None:
    """Assert Qwen route, Base64 MIME, JSON schema prompt, confidence and close."""
    transport.post.return_value = httpx.Response(
        200,
        request=httpx.Request("POST", "https://test"),
        json={"choices": [{"message": {"content": receipt_json()}}]},
    )
    extractor = QwenVLMReceiptExtractor(api_key="test-secret", test_mode=False)
    assert DocumentVLMClient is QwenVLMReceiptExtractor
    result = asyncio.run(extractor.extract_receipt(b"image", "image/png"))
    assert result.is_arithmetic_valid and result.confidence_score == 0.95
    call = transport.post.call_args
    assert call.args[0] == "https://openrouter.ai/api/v1/chat/completions"
    payload = call.kwargs["json"]
    assert payload["model"] == "qwen/qwen-2.5-vl-7b-instruct"
    assert payload["response_format"] == {"type": "json_object"}
    content = payload["messages"][0]["content"]
    assert (
        content[1]["image_url"]["url"]
        == "data:image/png;base64," + base64.b64encode(b"image").decode()
    )
    assert '"additionalProperties": false' in content[0]["text"]
    assert "không tư vấn tài chính" in content[0]["text"]
    assert "test-secret" not in repr(extractor.__dict__)
    asyncio.run(extractor.aclose())
    transport.aclose.assert_awaited_once()


@pytest.mark.parametrize(
    "content", ["invalid-json", "{}", "", "[]", '{"total_amount": "70000"}']
)
def test_invalid_output(transport: Mock, content: str) -> None:
    """Malformed or schema-invalid JSON cannot be saved as a receipt."""
    transport.post.return_value = httpx.Response(
        200,
        request=httpx.Request("POST", "https://test"),
        json={"choices": [{"message": {"content": content}}]},
    )
    extractor = QwenVLMReceiptExtractor(api_key="dummy", test_mode=False)
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert caught.value.reason == "validation"


@pytest.mark.parametrize(
    ("status", "reason"),
    [
        (400, "request"),
        (401, "auth"),
        (402, "quota"),
        (403, "auth"),
        (404, "model"),
        (429, "quota"),
        (503, "unavailable"),
        (504, "timeout"),
    ],
)
def test_http_failures(transport: Mock, status: int, reason: str) -> None:
    """Propagate safe error categories without provider bodies or credentials."""
    transport.post.return_value = httpx.Response(
        status,
        request=httpx.Request("POST", "https://test"),
        json={"error": {"message": "private-provider-payload"}},
    )
    extractor = QwenVLMReceiptExtractor(api_key="test-secret", test_mode=False)
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert caught.value.reason == reason and caught.value.status_code == status
    assert "private-provider-payload" not in str(caught.value)
    assert caught.value.__cause__ is None


@pytest.mark.parametrize(
    ("failure", "reason"),
    [
        (httpx.ConnectError("secret"), "network"),
        (httpx.ReadTimeout("secret"), "timeout"),
        (OSError("secret"), "network"),
    ],
)
def test_network_failures(transport: Mock, failure: Exception, reason: str) -> None:
    """Network failures never become fabricated successful extractions."""
    transport.post.side_effect = failure
    extractor = QwenVLMReceiptExtractor(api_key="dummy", test_mode=False)
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert caught.value.reason == reason and "secret" not in str(caught.value)


def test_outer_deadline(transport: Mock) -> None:
    """Cancel requests even if a stalled transport does not enforce HTTP timeout."""

    async def slow(*args: object, **kwargs: object) -> None:
        """Simulate a stalled asynchronous request."""
        await asyncio.sleep(1)

    transport.post.side_effect = slow
    extractor = QwenVLMReceiptExtractor(
        api_key="dummy", test_mode=False, timeout_seconds=0.001
    )
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert caught.value.reason == "timeout"


def test_provider_config_and_key_isolation(
    monkeypatch: pytest.MonkeyPatch, transport: Mock
) -> None:
    """Gemini keys cannot enable Qwen; DashScope and free models are configurable."""
    monkeypatch.setenv("OPENROUTER_API_KEY", "")
    monkeypatch.setenv("GEMINI_API_KEY", "gemini-secret")
    assert QwenVLMReceiptExtractor(test_mode=False).is_mock
    monkeypatch.setenv("DASHSCOPE_API_KEY", "dashscope-secret")
    monkeypatch.setenv("QWEN_MODEL", "")
    extractor = QwenVLMReceiptExtractor(
        base_url="https://dashscope.aliyuncs.com/compatible-mode/v1", test_mode=False
    )
    assert not extractor.is_mock and extractor.model_name == "qwen2.5-vl-7b-instruct"
    free = QwenVLMReceiptExtractor(
        api_key="dummy", model_name="qwen/qwen-2.5-vl-7b-instruct:free", test_mode=False
    )
    assert free.model_name.endswith(":free")


def test_test_environment_never_allocates_http(monkeypatch: pytest.MonkeyPatch) -> None:
    """An accidentally configured real key remains offline in default test mode."""
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-secret")
    constructor = Mock(side_effect=AssertionError("Network must stay offline"))
    monkeypatch.setattr(httpx, "AsyncClient", constructor)
    assert QwenVLMReceiptExtractor().is_mock
    constructor.assert_not_called()


@pytest.mark.parametrize(
    "body", [{}, {"choices": []}, {"choices": [{"message": {"content": None}}]}]
)
def test_missing_completion(transport: Mock, body: dict[str, object]) -> None:
    """Provider envelopes without a usable completion are validation failures."""
    transport.post.return_value = httpx.Response(
        200, request=httpx.Request("POST", "https://test"), json=body
    )
    extractor = QwenVLMReceiptExtractor(api_key="dummy", test_mode=False)
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert caught.value.reason == "validation"


def test_arithmetic_overrides_model_claims(transport: Mock) -> None:
    """A model's confident arithmetic claim cannot bypass Python validation."""
    body = json.loads(receipt_json())
    body.update(total_amount=100000, is_arithmetic_valid=True, confidence_score=1.0)
    transport.post.return_value = httpx.Response(
        200,
        request=httpx.Request("POST", "https://test"),
        json={"choices": [{"message": {"content": json.dumps(body)}}]},
    )
    extractor = QwenVLMReceiptExtractor(api_key="dummy", test_mode=False)
    result = asyncio.run(extractor.extract_receipt(b"image"))
    assert not result.is_arithmetic_valid and result.confidence_score == 0.60
    assert result.total_amount == 100000


@pytest.mark.parametrize("wrapped", [True, False])
def test_fpt_cloud_request_and_response(
    monkeypatch: pytest.MonkeyPatch, transport: Mock, wrapped: bool
) -> None:
    """Use FPT credentials/model and accept both documented completion formats."""
    monkeypatch.setenv("QWEN_BASE_URL", "https://mkp-api.fptcloud.com/v1")
    monkeypatch.setenv("QWEN_MODEL", "")
    monkeypatch.setenv("FPT_API_KEY", "fpt-test-secret")
    monkeypatch.setenv("OPENROUTER_API_KEY", "wrong-provider-secret")
    completion = {"choices": [{"message": {"content": receipt_json()}}]}
    body = {"code": 200, "data": completion} if wrapped else completion
    transport.post.return_value = httpx.Response(
        200, request=httpx.Request("POST", "https://test"), json=body
    )
    extractor = QwenVLMReceiptExtractor(test_mode=False)
    result = asyncio.run(extractor.extract_receipt(b"image", "image/png"))
    assert result.is_arithmetic_valid
    call = transport.post.call_args
    assert call.args[0] == "https://mkp-api.fptcloud.com/v1/chat/completions"
    assert call.kwargs["headers"]["Authorization"] == "Bearer fpt-test-secret"
    assert call.kwargs["json"]["model"] == "Qwen2.5-VL-7B-Instruct"
    assert call.kwargs["json"]["stream"] is False
    output_format = call.kwargs["json"]["response_format"]
    assert output_format["type"] == "json_schema"
    assert output_format["json_schema"]["strict"] is True
    assert output_format["json_schema"]["schema"]["additionalProperties"] is False
    asyncio.run(extractor.aclose())


def test_invalid_values_produce_safe_diagnostics(
    transport: Mock, caplog: pytest.LogCaptureFixture
) -> None:
    """Show the exact rejected field without logging model content or secrets."""
    body = json.loads(receipt_json())
    body["items"][0]["price"] = "private-sensitive-value"
    body["private-secret-field"] = "private-sensitive-value"
    transport.post.return_value = httpx.Response(
        200,
        request=httpx.Request("POST", "https://test"),
        json={"choices": [{"message": {"content": json.dumps(body)}}]},
    )
    extractor = QwenVLMReceiptExtractor(api_key="credential-secret", test_mode=False)
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert any("items.0.price" in detail for detail in caught.value.validation_details)
    for secret in (
        "private-sensitive-value",
        "private-secret-field",
        "credential-secret",
    ):
        assert secret not in caplog.text
        assert secret not in str(caught.value.validation_details)


def test_truncated_completion_is_distinguished(transport: Mock) -> None:
    """An incomplete response needs a length diagnostic rather than schema guesses."""
    transport.post.return_value = httpx.Response(
        200,
        request=httpx.Request("POST", "https://test"),
        json={
            "choices": [
                {"finish_reason": "length", "message": {"content": '{"items": ['}}
            ]
        },
    )
    extractor = QwenVLMReceiptExtractor(api_key="dummy", test_mode=False)
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert caught.value.reason == "truncated"
    assert caught.value.validation_details


def test_fpt_cloud_does_not_use_openrouter_key(
    monkeypatch: pytest.MonkeyPatch, transport: Mock
) -> None:
    """Missing FPT credentials cannot accidentally send an OpenRouter secret."""
    monkeypatch.setenv("QWEN_BASE_URL", "https://mkp-api.fptcloud.com/v1")
    monkeypatch.setenv("FPT_API_KEY", "")
    monkeypatch.setenv("OPENROUTER_API_KEY", "wrong-provider-secret")
    assert QwenVLMReceiptExtractor(test_mode=False).is_mock
    transport.post.assert_not_called()


def test_fpt_error_envelope(transport: Mock) -> None:
    """HTTP success with a provider error code cannot become receipt success."""
    transport.post.return_value = httpx.Response(
        200,
        request=httpx.Request("POST", "https://test"),
        json={"code": 500, "message": "private-provider-error", "data": {}},
    )
    extractor = QwenVLMReceiptExtractor(api_key="dummy", test_mode=False)
    with pytest.raises(CloudVLMError) as caught:
        asyncio.run(extractor.extract_receipt(b"image"))
    assert caught.value.reason == "service"
    assert "private-provider-error" not in str(caught.value)
