"""Tests for cloud_vlm _common module."""

from pathlib import Path
from unittest.mock import patch

import pytest

from app.infrastructure.ai.cloud_vlm import _common
from app.infrastructure.ai.cloud_vlm._common import (
    PROJECT_ROOT,
    CloudVLMError,
    configured_value,
)


class TestConfiguredValue:
    """Read configuration using isolated files and restored environment values."""

    @pytest.fixture(autouse=True)
    def isolated_config(self, tmp_path, monkeypatch):
        monkeypatch.setattr(_common, "PROJECT_ROOT", tmp_path)
        monkeypatch.delenv("TEST_CLOUD_VLM_KEY", raising=False)
        (tmp_path / "backend").mkdir()
        self.root = tmp_path

    def write_env(self, path, value):
        (self.root / path).write_text(f"TEST_CLOUD_VLM_KEY={value}\n", encoding="utf-8")

    def test_configured_value_from_env(self, monkeypatch):
        monkeypatch.setenv("TEST_CLOUD_VLM_KEY", "env_value")
        assert configured_value("TEST_CLOUD_VLM_KEY") == "env_value"

    def test_configured_value_env_priority_over_dotenv(self, monkeypatch):
        self.write_env("backend/.env", "backend_value")
        monkeypatch.setenv("TEST_CLOUD_VLM_KEY", "env_value")
        with patch("dotenv.dotenv_values") as mock_dotenv:
            assert configured_value("TEST_CLOUD_VLM_KEY") == "env_value"
            mock_dotenv.assert_not_called()

    def test_configured_value_from_backend_dotenv(self):
        self.write_env("backend/.env", "backend_value")
        self.write_env(".env", "root_value")
        assert configured_value("TEST_CLOUD_VLM_KEY") == "backend_value"

    def test_configured_value_from_root_dotenv(self):
        self.write_env(".env", "root_value")
        assert configured_value("TEST_CLOUD_VLM_KEY") == "root_value"

    def test_configured_value_not_found_returns_none(self):
        assert configured_value("TEST_CLOUD_VLM_KEY") is None

    def test_configured_value_empty_string_in_dotenv(self):
        self.write_env("backend/.env", "")
        assert configured_value("TEST_CLOUD_VLM_KEY") is None

    def test_empty_backend_value_falls_back_to_root(self):
        self.write_env("backend/.env", "")
        self.write_env(".env", "root_value")
        assert configured_value("TEST_CLOUD_VLM_KEY") == "root_value"


class TestCloudVLMError:
    """Tests for CloudVLMError exception."""

    def test_init_with_defaults(self):
        """Test CloudVLMError initialization with defaults."""
        error = CloudVLMError("Test error message")
        assert str(error) == "Test error message"
        assert error.reason == "service"
        assert error.status_code is None
        assert error.validation_details == ()

    def test_init_with_custom_reason(self):
        """Test CloudVLMError initialization with custom reason."""
        error = CloudVLMError("Test error", reason="auth")
        assert error.reason == "auth"

    def test_init_with_status_code(self):
        """Test CloudVLMError initialization with status code."""
        error = CloudVLMError("Test error", status_code=429)
        assert error.status_code == 429

    def test_init_with_validation_details(self):
        """Test CloudVLMError initialization with validation details."""
        error = CloudVLMError("Test error", validation_details=("field1", "field2"))
        assert error.validation_details == ("field1", "field2")

    def test_init_with_all_params(self):
        """Test CloudVLMError initialization with all parameters."""
        error = CloudVLMError(
            "Test error",
            reason="validation",
            status_code=400,
            validation_details=("field1", "field2"),
        )
        assert str(error) == "Test error"
        assert error.reason == "validation"
        assert error.status_code == 400
        assert error.validation_details == ("field1", "field2")

    def test_inheritance_from_runtime_error(self):
        """Test CloudVLMError inherits from RuntimeError."""
        error = CloudVLMError("Test error")
        assert isinstance(error, RuntimeError)

    def test_error_attributes_retained(self):
        """Test that error attributes are retained for caller inspection."""
        error = CloudVLMError(
            "Service unavailable",
            reason="timeout",
            status_code=504,
            validation_details=("request_id",),
        )
        # Caller can access these for retry logic
        assert error.reason == "timeout"
        assert error.status_code == 504
        assert error.validation_details == ("request_id",)


class TestProjectRoot:
    """Tests for PROJECT_ROOT constant."""

    def test_project_root_is_path(self):
        """Test PROJECT_ROOT is a Path object."""
        assert isinstance(PROJECT_ROOT, Path)

    def test_project_root_points_to_correct_location(self):
        """Resolve the shared project root from the provider module."""
        assert PROJECT_ROOT == Path(_common.__file__).resolve().parents[5]
