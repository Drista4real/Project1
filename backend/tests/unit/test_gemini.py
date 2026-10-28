"""Unit tests for Gemini transport module."""

import os
import sys
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pydantic import BaseModel

from app.infrastructure.ai.cloud_vlm import _gemini
from app.infrastructure.ai.cloud_vlm._common import CloudVLMError
from app.infrastructure.ai.cloud_vlm._gemini import (
    _configured_value,
    configured_api_key,
    configured_input_model_name,
    configured_model_name,
    create_client,
    generate_structured,
)


@pytest.fixture(autouse=True)
def isolated_gemini_config(tmp_path, monkeypatch):
    monkeypatch.setattr(_gemini, "PROJECT_ROOT", tmp_path)
    for name in (
        "TEST_KEY",
        "MISSING_KEY",
        "GEMINI_API_KEY",
        "GEMINI_MODEL",
        "GEMINI_INPUT_MODEL",
    ):
        monkeypatch.delenv(name, raising=False)


class SampleSchema(BaseModel):
    name: str
    value: int


class TestConfiguredValue:
    """Tests for _configured_value function."""

    def test_reads_from_environment(self):
        """Test reading value from environment variable."""
        with patch.dict(os.environ, {"TEST_KEY": "env_value"}):
            result = _configured_value("TEST_KEY")
            assert result == "env_value"

    def test_reads_from_dotenv_file(self, tmp_path: Path):
        """Test reading value from .env file when not in environment."""
        env_file = tmp_path / ".env"
        env_file.write_text("TEST_KEY=dotenv_value\n")
        with patch("app.infrastructure.ai.cloud_vlm._gemini.PROJECT_ROOT", tmp_path):
            with patch.dict(os.environ, {}, clear=True):
                result = _configured_value("TEST_KEY")
                assert result == "dotenv_value"

    def test_returns_none_when_missing(self, tmp_path, monkeypatch):
        """Test returning None when key not found."""
        monkeypatch.setattr(_gemini, "PROJECT_ROOT", tmp_path)
        monkeypatch.delenv("MISSING_KEY", raising=False)
        result = _configured_value("MISSING_KEY")
        assert result is None


class TestConfiguredApiKey:
    """Tests for configured_api_key function."""

    def test_reads_gemini_api_key(self):
        """Test reading GEMINI_API_KEY."""
        with patch.dict(os.environ, {"GEMINI_API_KEY": "test_key_123"}):
            result = configured_api_key()
            assert result == "test_key_123"


class TestConfiguredModelName:
    """Tests for configured_model_name function."""

    def test_default_model(self):
        """Test default model when not configured."""
        with patch(
            "app.infrastructure.ai.cloud_vlm._gemini._configured_value",
            return_value=None,
        ):
            result = configured_model_name()
            assert result == "gemini-2.5-flash"

    def test_custom_model(self):
        """Test custom model from environment."""
        with patch(
            "app.infrastructure.ai.cloud_vlm._gemini._configured_value",
            return_value="gemini-custom",
        ):
            result = configured_model_name()
            assert result == "gemini-custom"


class TestConfiguredInputModelName:
    """Tests for configured_input_model_name function."""

    def test_default_input_model(self):
        """Test default input model when not configured."""
        with patch(
            "app.infrastructure.ai.cloud_vlm._gemini._configured_value",
            return_value=None,
        ):
            result = configured_input_model_name()
            assert result == "gemini-3.1-flash-lite"

    def test_custom_input_model(self):
        """Test custom input model from environment."""
        with patch(
            "app.infrastructure.ai.cloud_vlm._gemini._configured_value",
            return_value="gemini-input-custom",
        ):
            result = configured_input_model_name()
            assert result == "gemini-input-custom"


class TestCreateClient:
    """Tests for create_client function."""

    def test_rejects_invalid_timeout(self):
        """Test rejecting non-finite timeout."""
        with pytest.raises(
            ValueError, match="timeout_seconds must be finite and positive"
        ):
            create_client(None, None, float("inf"))
        with pytest.raises(
            ValueError, match="timeout_seconds must be finite and positive"
        ):
            create_client(None, None, -1)
        with pytest.raises(
            ValueError, match="timeout_seconds must be finite and positive"
        ):
            create_client(None, None, 0)

    def test_returns_none_in_test_mode(self):
        """Test returning None when test_mode is True."""
        result = create_client("test_key", True, 10.0)
        assert result is None

    def test_returns_none_in_pytest(self):
        """Test returning None when running under pytest."""
        with patch.dict(sys.modules, {"pytest": MagicMock()}):
            result = create_client("test_key", None, 10.0)
            assert result is None

    def test_returns_none_when_no_key(self):
        """Test returning None when no API key available."""
        with patch(
            "app.infrastructure.ai.cloud_vlm._gemini.configured_api_key",
            return_value=None,
        ):
            result = create_client(None, False, 10.0)
            assert result is None

    def test_returns_none_for_empty_key(self):
        """Test returning None for empty API key."""
        result = create_client("", False, 10.0)
        assert result is None

    def test_returns_none_for_whitespace_key(self):
        """Test returning None for whitespace-only API key."""
        result = create_client("   ", False, 10.0)
        assert result is None


class TestGenerateStructured:
    """Tests for generate_structured function."""

    @pytest.mark.asyncio
    async def test_timeout_raises_cloud_vlm_error(self):
        """Test timeout raises CloudVLMError with reason=timeout."""
        mock_client = MagicMock()
        mock_client.aio.models.generate_content = AsyncMock(
            side_effect=TimeoutError("Timeout")
        )

        with pytest.raises(CloudVLMError) as exc_info:
            await generate_structured(
                mock_client, "gemini-test", "test content", SampleSchema, 1.0
            )
        assert exc_info.value.reason == "timeout"

    @pytest.mark.asyncio
    async def test_api_error_401_raises_auth(self):
        """Test 401 API error raises CloudVLMError with reason=auth."""
        from google.genai import errors

        mock_client = MagicMock()
        # APIError requires code and response_json
        api_error = errors.APIError(
            code=401, response_json={"error": {"message": "Unauthorized"}}
        )
        mock_client.aio.models.generate_content = AsyncMock(side_effect=api_error)

        with pytest.raises(CloudVLMError) as exc_info:
            await generate_structured(
                mock_client, "gemini-test", "test content", SampleSchema, 10.0
            )
        assert exc_info.value.reason == "auth"
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_api_error_429_raises_quota(self):
        """Test 429 API error raises CloudVLMError with reason=quota."""
        from google.genai import errors

        mock_client = MagicMock()
        api_error = errors.APIError(
            code=429, response_json={"error": {"message": "Quota exceeded"}}
        )
        mock_client.aio.models.generate_content = AsyncMock(side_effect=api_error)

        with pytest.raises(CloudVLMError) as exc_info:
            await generate_structured(
                mock_client, "gemini-test", "test content", SampleSchema, 10.0
            )
        assert exc_info.value.reason == "quota"

    @pytest.mark.asyncio
    async def test_network_error_raises_network(self):
        """Test network error raises CloudVLMError with reason=network."""
        import httpx

        mock_client = MagicMock()
        mock_client.aio.models.generate_content = AsyncMock(
            side_effect=httpx.HTTPError("Network error")
        )

        with pytest.raises(CloudVLMError) as exc_info:
            await generate_structured(
                mock_client, "gemini-test", "test content", SampleSchema, 10.0
            )
        assert exc_info.value.reason == "network"

    @pytest.mark.asyncio
    async def test_validation_error_raises_validation(self):
        """Test validation error raises CloudVLMError with reason=validation."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.parsed = {"name": "test", "value": "not_an_int"}
        mock_response.text = None
        mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

        with pytest.raises(CloudVLMError) as exc_info:
            await generate_structured(
                mock_client, "gemini-test", "test content", SampleSchema, 10.0
            )
        assert exc_info.value.reason == "validation"

    @pytest.mark.asyncio
    async def test_no_structured_output_raises_validation(self):
        """Test empty response raises validation error."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.parsed = None
        mock_response.text = ""
        mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

        with pytest.raises(CloudVLMError) as exc_info:
            await generate_structured(
                mock_client, "gemini-test", "test content", SampleSchema, 10.0
            )
        assert exc_info.value.reason == "validation"

    @pytest.mark.asyncio
    async def test_successful_response_returns_validated_model(self):
        """Test successful response returns validated model."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.parsed = {"name": "test", "value": 42}
        mock_response.text = '{"name": "test", "value": 42}'
        mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)

        result = await generate_structured(
            mock_client, "gemini-test", "test content", SampleSchema, 10.0
        )
        assert isinstance(result, SampleSchema)
        assert result.name == "test"
        assert result.value == 42
