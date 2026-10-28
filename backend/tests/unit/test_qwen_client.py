"""Unit tests for Qwen VLM client module."""

import json
from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

from app.infrastructure.ai.cloud_vlm import _common
from app.infrastructure.ai.cloud_vlm._common import CloudVLMError
from app.infrastructure.ai.cloud_vlm.qwen_client import (
    QwenVLMReceiptExtractor,
    ReceiptOutputError,
    _schema_errors,
    check_receipt_arithmetic,
    parse_receipt_content,
)
from app.infrastructure.ai.cloud_vlm.schemas import (
    ReceiptExtractionResult,
    ReceiptItemSchema,
)


@pytest.fixture(autouse=True)
def isolated_qwen_config(tmp_path, monkeypatch):
    monkeypatch.setattr(_common, "PROJECT_ROOT", tmp_path)
    for name in (
        "QWEN_BASE_URL",
        "QWEN_MODEL",
        "QWEN_API_KEY",
        "OPENROUTER_API_KEY",
        "DASHSCOPE_API_KEY",
        "FPT_API_KEY",
    ):
        monkeypatch.delenv(name, raising=False)


class TestReceiptOutputError:
    """Tests for ReceiptOutputError."""

    def test_stores_details(self):
        """Test storing validation details."""
        error = ReceiptOutputError(("field1: error1", "field2: error2"))
        assert error.details == ("field1: error1", "field2: error2")
        assert str(error) == "Receipt output failed validation"


class TestSchemaErrors:
    """Tests for _schema_errors function."""

    def test_maps_known_error_types(self):
        """
        Test mapping known Pydantic error types to Vietnamese descriptions (first 5).
        """
        mock_error = MagicMock()
        mock_error.errors.return_value = [
            {"loc": ("merchant_name",), "type": "missing"},
            {"loc": ("items", 0, "quantity"), "type": "int_type"},
            {"loc": ("category",), "type": "literal_error"},
            {"loc": ("extra_field",), "type": "extra_forbidden"},
            {"loc": ("price",), "type": "greater_than_equal"},
            {"loc": ("transaction_date",), "type": "string_pattern_mismatch"},
        ]
        result = _schema_errors(mock_error)
        assert "thiếu trường bắt buộc" in result[0]
        assert "cần số nguyên" in result[1]
        assert "danh mục không thuộc" in result[2]
        assert "có trường ngoài schema" in result[3]
        assert "giá trị nhỏ hơn giới hạn" in result[4]
        # Function limits to 5 errors, so index 5 doesn't exist
        assert len(result) == 5

    def test_limits_to_five_errors(self):
        """Test limiting to first 5 errors."""
        mock_error = MagicMock()
        mock_error.errors.return_value = [
            {"loc": ("field",), "type": "missing"} for _ in range(10)
        ]
        result = _schema_errors(mock_error)
        assert len(result) == 5


class TestParseReceiptContent:
    """Tests for parse_receipt_content function."""

    def test_valid_json_string(self):
        """Test parsing valid JSON string."""
        content = json.dumps(
            {
                "merchant_name": "Test",
                "items": [{"name": "Item", "quantity": 1, "price": 1000}],
                "total_amount": 1000,
                "category": "Ăn uống",
                "confidence_score": 0.9,
            },
            ensure_ascii=False,
        )
        result = parse_receipt_content(content)
        assert isinstance(result, ReceiptExtractionResult)
        assert result.merchant_name == "Test"

    def test_json_with_markdown_fence(self):
        """Test parsing JSON wrapped in markdown fence."""
        content = (
            '```json\n{"merchant_name": "Test", "items": [], "total_amount": 0, '
            '"category": "Khác", "confidence_score": 0.5}\n```'
        )
        result = parse_receipt_content(content)
        assert isinstance(result, ReceiptExtractionResult)

    def test_rejects_non_string(self):
        """Test rejecting non-string input."""
        with pytest.raises(ReceiptOutputError) as exc_info:
            parse_receipt_content(123)  # type: ignore
        assert "không có nội dung JSON dạng văn bản" in exc_info.value.details[0]

    def test_rejects_invalid_json(self):
        """Test rejecting invalid JSON."""
        with pytest.raises(ReceiptOutputError) as exc_info:
            parse_receipt_content("not valid json")
        assert "cú pháp không hợp lệ" in exc_info.value.details[0]

    def test_converts_vietnamese_date(self):
        """Test converting DD/MM/YYYY to YYYY-MM-DD."""
        content = json.dumps(
            {
                "merchant_name": "Test",
                "transaction_date": "12/10/2026",
                "items": [],
                "total_amount": 0,
                "category": "Khác",
                "confidence_score": 0.5,
            },
            ensure_ascii=False,
        )
        result = parse_receipt_content(content)
        assert result.transaction_date == "2026-10-12"

    def test_rejects_invalid_date_format(self):
        """Test rejecting invalid date format."""
        content = json.dumps(
            {
                "merchant_name": "Test",
                "transaction_date": "invalid",
                "items": [],
                "total_amount": 0,
                "category": "Khác",
                "confidence_score": 0.5,
            },
            ensure_ascii=False,
        )
        with pytest.raises(ReceiptOutputError) as exc_info:
            parse_receipt_content(content)
        assert "ngày cần định dạng YYYY-MM-DD" in exc_info.value.details[0]

    def test_rejects_nonexistent_date(self):
        """Test rejecting nonexistent date (e.g., Feb 30)."""
        content = json.dumps(
            {
                "merchant_name": "Test",
                "transaction_date": "30/02/2026",
                "items": [],
                "total_amount": 0,
                "category": "Khác",
                "confidence_score": 0.5,
            },
            ensure_ascii=False,
        )
        with pytest.raises(ReceiptOutputError) as exc_info:
            parse_receipt_content(content)
        assert "ngày không tồn tại" in exc_info.value.details[0]

    def test_handles_none_date(self):
        """Test handling null date."""
        content = json.dumps(
            {
                "merchant_name": "Test",
                "transaction_date": None,
                "items": [],
                "total_amount": 0,
                "category": "Khác",
                "confidence_score": 0.5,
            },
            ensure_ascii=False,
        )
        result = parse_receipt_content(content)
        assert result.transaction_date is None


class TestCheckReceiptArithmetic:
    """Tests for check_receipt_arithmetic function."""

    def test_valid_arithmetic(self):
        """Test valid arithmetic within 5% tolerance."""
        receipt = ReceiptExtractionResult(
            merchant_name="Test",
            items=[ReceiptItemSchema(name="Item 1", quantity=2, price=5000)],
            total_amount=10000,
            category="Ăn uống",
            confidence_score=0.9,
        )
        result = check_receipt_arithmetic(receipt)
        assert result.is_arithmetic_valid is True
        assert result.confidence_score == 0.95

    def test_invalid_arithmetic(self):
        """Test invalid arithmetic outside 5% tolerance."""
        receipt = ReceiptExtractionResult(
            merchant_name="Test",
            items=[ReceiptItemSchema(name="Item 1", quantity=2, price=5000)],
            total_amount=20000,  # 2x the sum - outside 5%
            category="Ăn uống",
            confidence_score=0.9,
        )
        result = check_receipt_arithmetic(receipt)
        assert result.is_arithmetic_valid is False
        assert result.confidence_score == 0.60

    def test_empty_items_invalid(self):
        """Test empty items list is invalid."""
        receipt = ReceiptExtractionResult(
            merchant_name="Test",
            items=[],
            total_amount=0,
            category="Khác",
            confidence_score=0.5,
        )
        result = check_receipt_arithmetic(receipt)
        assert result.is_arithmetic_valid is False

    def test_zero_total_valid(self):
        """Test zero total with zero items is valid."""
        receipt = ReceiptExtractionResult(
            merchant_name="Test",
            items=[ReceiptItemSchema(name="Item", quantity=1, price=0)],
            total_amount=0,
            category="Khác",
            confidence_score=0.5,
        )
        result = check_receipt_arithmetic(receipt)
        assert result.is_arithmetic_valid is True


class TestQwenVLMReceiptExtractorInit:
    """Tests for QwenVLMReceiptExtractor initialization."""

    def test_rejects_invalid_timeout(self):
        """Test rejecting non-finite timeout."""
        with pytest.raises(
            ValueError, match="timeout_seconds must be finite and positive"
        ):
            QwenVLMReceiptExtractor(timeout_seconds=float("inf"))
        with pytest.raises(
            ValueError, match="timeout_seconds must be finite and positive"
        ):
            QwenVLMReceiptExtractor(timeout_seconds=0)

    def test_rejects_non_https_url(self):
        """Test rejecting non-HTTPS base URL."""
        with pytest.raises(ValueError, match="Qwen base URL must be HTTPS"):
            QwenVLMReceiptExtractor(base_url="http://localhost:8000")

    def test_rejects_url_with_credentials(self):
        """Test rejecting URL with credentials."""
        with pytest.raises(ValueError, match="Qwen base URL must be HTTPS"):
            QwenVLMReceiptExtractor(base_url="https://user:pass@api.example.com")

    def test_rejects_url_with_query(self):
        """Test rejecting URL with query string."""
        with pytest.raises(ValueError, match="Qwen base URL must be HTTPS"):
            QwenVLMReceiptExtractor(base_url="https://api.example.com?param=value")

    def test_rejects_url_with_fragment(self):
        """Test rejecting URL with fragment."""
        with pytest.raises(ValueError, match="Qwen base URL must be HTTPS"):
            QwenVLMReceiptExtractor(base_url="https://api.example.com#fragment")

    def test_sets_is_mock_when_no_key(self):
        """Test is_mock is True when no API key."""
        with patch(
            "app.infrastructure.ai.cloud_vlm.qwen_client.configured_value",
            return_value=None,
        ):
            extractor = QwenVLMReceiptExtractor(test_mode=True)
            assert extractor.is_mock is True

    def test_sets_is_mock_when_test_mode(self):
        """Test is_mock is True when test_mode is True."""
        extractor = QwenVLMReceiptExtractor(api_key="test", test_mode=True)
        assert extractor.is_mock is True

    def test_sets_correct_model_for_dashscope(self):
        """Test setting correct model for DashScope."""
        with patch(
            "app.infrastructure.ai.cloud_vlm.qwen_client.configured_value",
            return_value=None,
        ):
            extractor = QwenVLMReceiptExtractor(
                base_url="https://dashscope.aliyuncs.com/api/v1",
                test_mode=True,
            )
            assert "qwen2.5-vl-7b-instruct" in extractor.model_name

    def test_sets_correct_model_for_fpt(self):
        """Test setting correct model for FPT Cloud."""
        with patch(
            "app.infrastructure.ai.cloud_vlm.qwen_client.configured_value",
            return_value=None,
        ):
            extractor = QwenVLMReceiptExtractor(
                base_url="https://mkp-api.fptcloud.com/api/v1",
                test_mode=True,
            )
            assert extractor.model_name == "Qwen2.5-VL-7B-Instruct"
            assert extractor._use_json_schema is True


class TestQwenVLMReceiptExtractorExtractReceipt:
    """Tests for extract_receipt method."""

    @pytest.mark.asyncio
    async def test_rejects_empty_image(self):
        """Test rejecting empty image bytes."""
        extractor = QwenVLMReceiptExtractor(test_mode=True)
        with pytest.raises(ValueError, match="Receipt image must be nonempty bytes"):
            await extractor.extract_receipt(b"")

    @pytest.mark.asyncio
    async def test_rejects_invalid_mime_type(self):
        """Test rejecting unsupported MIME type."""
        extractor = QwenVLMReceiptExtractor(test_mode=True)
        with pytest.raises(ValueError, match="Supported receipt MIME types"):
            await extractor.extract_receipt(b"fake", "image/gif")

    @pytest.mark.asyncio
    async def test_returns_mock_when_no_client(self):
        """Test returning mock receipt when client is None (mock mode)."""
        extractor = QwenVLMReceiptExtractor(test_mode=True)
        result = await extractor.extract_receipt(b"fake_image")
        assert isinstance(result, ReceiptExtractionResult)
        assert result.merchant_name == "Quán mẫu (MOCK)"
        # After check_receipt_arithmetic, valid mock gets confidence 0.95
        assert result.confidence_score == 0.95
        assert result.is_arithmetic_valid is True

    @pytest.mark.asyncio
    async def test_timeout_raises_cloud_vlm_error(self):
        """Test timeout raises CloudVLMError."""
        mock_client = AsyncMock()
        mock_client.post.side_effect = TimeoutError("Timeout")

        extractor = QwenVLMReceiptExtractor(
            api_key="test_key",
            test_mode=False,
            base_url="https://openrouter.ai/api/v1",
        )
        extractor._client = mock_client
        extractor.is_mock = False

        with pytest.raises(CloudVLMError) as exc_info:
            await extractor.extract_receipt(b"fake_image")
        assert exc_info.value.reason == "timeout"

    @pytest.mark.asyncio
    async def test_http_401_raises_auth_error(self):
        """Test HTTP 401 raises auth error."""
        mock_client = AsyncMock()
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_client.post.side_effect = httpx.HTTPStatusError(
            "Unauthorized", request=MagicMock(), response=mock_response
        )

        extractor = QwenVLMReceiptExtractor(
            api_key="test_key",
            test_mode=False,
            base_url="https://openrouter.ai/api/v1",
        )
        extractor._client = mock_client
        extractor.is_mock = False

        with pytest.raises(CloudVLMError) as exc_info:
            await extractor.extract_receipt(b"fake_image")
        assert exc_info.value.reason == "auth"
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_http_429_raises_quota_error(self):
        """Test HTTP 429 raises quota error."""
        mock_client = AsyncMock()
        mock_response = MagicMock()
        mock_response.status_code = 429
        mock_client.post.side_effect = httpx.HTTPStatusError(
            "Quota exceeded", request=MagicMock(), response=mock_response
        )

        extractor = QwenVLMReceiptExtractor(
            api_key="test_key",
            test_mode=False,
            base_url="https://openrouter.ai/api/v1",
        )
        extractor._client = mock_client
        extractor.is_mock = False

        with pytest.raises(CloudVLMError) as exc_info:
            await extractor.extract_receipt(b"fake_image")
        assert exc_info.value.reason == "quota"

    @pytest.mark.asyncio
    async def test_network_error_raises_network_error(self):
        """Test network error raises network error."""
        mock_client = AsyncMock()
        mock_client.post.side_effect = httpx.HTTPError("Network error")

        extractor = QwenVLMReceiptExtractor(
            api_key="test_key",
            test_mode=False,
            base_url="https://openrouter.ai/api/v1",
        )
        extractor._client = mock_client
        extractor.is_mock = False

        with pytest.raises(CloudVLMError) as exc_info:
            await extractor.extract_receipt(b"fake_image")
        assert exc_info.value.reason == "network"

    @pytest.mark.asyncio
    async def test_truncated_response_raises_error(self):
        """Test truncated response raises CloudVLMError."""
        mock_client = AsyncMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "choices": [
                {
                    "finish_reason": "length",
                    "message": {
                        "content": json.dumps(
                            {
                                "merchant_name": "Test",
                                "items": [],
                                "total_amount": 0,
                                "category": "Khác",
                                "confidence_score": 0.5,
                            },
                            ensure_ascii=False,
                        )
                    },
                }
            ]
        }
        mock_client.post.return_value = mock_response

        extractor = QwenVLMReceiptExtractor(
            api_key="test_key",
            test_mode=False,
            base_url="https://openrouter.ai/api/v1",
        )
        extractor._client = mock_client
        extractor.is_mock = False

        with pytest.raises(CloudVLMError) as exc_info:
            await extractor.extract_receipt(b"fake_image")
        assert exc_info.value.reason == "truncated"

    @pytest.mark.asyncio
    async def test_invalid_json_response_raises_validation_error(self):
        """Test invalid JSON response raises validation error."""
        mock_client = AsyncMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "choices": [{"finish_reason": "stop", "message": {"content": "not json"}}]
        }
        mock_client.post.return_value = mock_response

        extractor = QwenVLMReceiptExtractor(
            api_key="test_key",
            test_mode=False,
            base_url="https://openrouter.ai/api/v1",
        )
        extractor._client = mock_client
        extractor.is_mock = False

        with pytest.raises(CloudVLMError) as exc_info:
            await extractor.extract_receipt(b"fake_image")
        assert exc_info.value.reason == "validation"

    @pytest.mark.asyncio
    async def test_fpt_envelope_error_raises_service_error(self):
        """Test FPT envelope with non-200 code raises service error."""
        mock_client = AsyncMock()
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "code": 500,
            "message": "Internal error",
            "choices": [
                {
                    "finish_reason": "stop",
                    "message": {
                        "content": json.dumps(
                            {
                                "merchant_name": "Test",
                                "items": [],
                                "total_amount": 0,
                                "category": "Khác",
                                "confidence_score": 0.5,
                            },
                            ensure_ascii=False,
                        )
                    },
                }
            ],
        }
        mock_client.post.return_value = mock_response

        extractor = QwenVLMReceiptExtractor(
            api_key="test_key",
            test_mode=False,
            base_url="https://mkp-api.fptcloud.com/api/v1",
        )
        extractor._client = mock_client
        extractor.is_mock = False

        with pytest.raises(CloudVLMError) as exc_info:
            await extractor.extract_receipt(b"fake_image")
        assert exc_info.value.reason == "service"


class TestQwenVLMReceiptExtractorAclose:
    """Tests for aclose method."""

    @pytest.mark.asyncio
    async def test_closes_client_when_exists(self):
        """Test closing client when it exists."""
        mock_client = AsyncMock()
        extractor = QwenVLMReceiptExtractor(test_mode=True)
        extractor._client = mock_client
        extractor.is_mock = False

        await extractor.aclose()
        mock_client.aclose.assert_awaited_once()

    @pytest.mark.asyncio
    async def test_no_op_when_no_client(self):
        """Test no-op when client is None."""
        extractor = QwenVLMReceiptExtractor(test_mode=True)
        extractor._client = None
        await extractor.aclose()  # Should not raise


class TestQwenVLMReceiptExtractorExtract:
    """Tests for extract method (domain interface)."""

    @pytest.mark.asyncio
    async def test_converts_to_domain_receipt_data(self):
        """Test converting extraction result to domain ReceiptData."""
        extractor = QwenVLMReceiptExtractor(test_mode=True)
        result = await extractor.extract(b"fake_image")

        from app.domain.interfaces.vlm_interface import ReceiptData

        assert isinstance(result, ReceiptData)
        assert result.merchant == "Quán mẫu (MOCK)"
        assert result.total == 35000
        assert len(result.items) == 1
