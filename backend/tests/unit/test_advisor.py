"""Unit tests for Financial Advisor module."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pydantic import SecretStr

from app.infrastructure.ai.cloud_vlm._common import CloudVLMError
from app.infrastructure.ai.cloud_vlm.advisor import (
    PersonaFinancialAdvisor,
    _finite,
    _short_message,
)
from app.infrastructure.ai.cloud_vlm.schemas import AdvisorAlertResponse


class TestFinite:
    """Tests for _finite validator."""

    def test_valid_float(self):
        """Test valid float input."""
        assert _finite(100.5, "test") == 100.5

    def test_valid_int(self):
        """Test valid int input."""
        assert _finite(100, "test") == 100.0

    def test_rejects_boolean(self):
        """Test rejecting boolean."""
        with pytest.raises(ValueError, match="test must be finite"):
            _finite(True, "test")

    def test_rejects_nan(self):
        """Test rejecting NaN."""
        with pytest.raises(ValueError, match="test must be finite"):
            _finite(float("nan"), "test")

    def test_rejects_infinity(self):
        """Test rejecting infinity."""
        with pytest.raises(ValueError, match="test must be finite"):
            _finite(float("inf"), "test")

    def test_rejects_non_numeric(self):
        """Test rejecting non-numeric."""
        with pytest.raises(ValueError, match="test must be finite"):
            _finite("not a number", "test")


class TestShortMessage:
    """Tests for _short_message function."""

    def test_keeps_first_two_sentences(self):
        """Test keeping first two sentences."""
        text = "First sentence. Second sentence. Third sentence."
        result = _short_message(text, sentences=2)
        assert result == "First sentence. Second sentence."

    def test_keeps_single_sentence(self):
        """Test keeping one sentence."""
        text = "First sentence. Second sentence."
        result = _short_message(text, sentences=1)
        assert result == "First sentence."

    def test_strips_whitespace(self):
        """Test stripping whitespace."""
        text = "  First sentence. Second sentence.  "
        result = _short_message(text, sentences=2)
        assert result == "First sentence. Second sentence."

    def test_preserves_thousands_separators(self):
        """Test preserving thousands separators in prose."""
        text = "Amount is 1,000,000. It is large."
        result = _short_message(text, sentences=2)
        assert result == "Amount is 1,000,000. It is large."


class TestPersonaFinancialAdvisorInit:
    """Tests for PersonaFinancialAdvisor initialization."""

    def test_init_with_defaults(self):
        """Test initialization with default parameters."""
        with patch(
            "app.infrastructure.ai.cloud_vlm.advisor.create_client", return_value=None
        ):
            advisor = PersonaFinancialAdvisor()
            assert advisor.model_name == "gemini-2.5-flash"
            assert advisor.timeout_seconds == 10.0
            assert advisor._client is None
            assert advisor.is_mock is True

    def test_init_with_custom_params(self):
        """Test initialization with custom parameters."""
        with patch(
            "app.infrastructure.ai.cloud_vlm.advisor.create_client",
            return_value=MagicMock(),
        ):
            advisor = PersonaFinancialAdvisor(
                api_key="test_key",
                test_mode=False,
                timeout_seconds=15.0,
                model_name="custom-model",
            )
            assert advisor.model_name == "custom-model"
            assert advisor.timeout_seconds == 15.0
            assert advisor.is_mock is False

    def test_init_with_secret_str(self):
        """Test initialization with SecretStr API key."""
        with patch(
            "app.infrastructure.ai.cloud_vlm.advisor.create_client", return_value=None
        ):
            advisor = PersonaFinancialAdvisor(api_key=SecretStr("secret_key"))
            assert advisor.is_mock is True


class TestPersonaFinancialAdvisorWarning:
    """Tests for _warning method."""

    @pytest.mark.asyncio
    async def test_returns_fallback_when_no_client(self):
        """Test returning fallback when no client."""
        advisor = PersonaFinancialAdvisor()
        advisor._client = None
        fallback = AdvisorAlertResponse(
            alert_type="SAFE",
            message="Safe message",
            suggested_action="Safe action",
        )
        result = await advisor._warning(fallback, {}, "test persona")
        assert result == fallback

    @pytest.mark.asyncio
    async def test_returns_fallback_on_cloud_vlm_error(self):
        """Test returning fallback on CloudVLMError."""
        mock_client = AsyncMock()
        advisor = PersonaFinancialAdvisor()
        advisor._client = mock_client

        with patch(
            "app.infrastructure.ai.cloud_vlm.advisor.generate_structured",
            side_effect=CloudVLMError("Error"),
        ):
            fallback = AdvisorAlertResponse(
                alert_type="SAFE",
                message="Safe message",
                suggested_action="Safe action",
            )
            result = await advisor._warning(fallback, {}, "test persona")
            assert result == fallback

    @pytest.mark.asyncio
    async def test_returns_fallback_on_validation_error(self):
        """Test returning fallback when response has numbers."""
        mock_client = AsyncMock()
        advisor = PersonaFinancialAdvisor()
        advisor._client = mock_client

        # Response with numbers in message should be rejected
        invalid_response = AdvisorAlertResponse(
            alert_type="SAFE",
            message="Balance is 1000000 VND",  # Contains numbers
            suggested_action="Action",
        )
        with patch(
            "app.infrastructure.ai.cloud_vlm.advisor.generate_structured",
            return_value=invalid_response,
        ):
            fallback = AdvisorAlertResponse(
                alert_type="SAFE",
                message="Safe message",
                suggested_action="Safe action",
            )
            result = await advisor._warning(fallback, {}, "test persona")
            assert result == fallback

    @pytest.mark.asyncio
    async def test_returns_fallback_on_wrong_alert_type(self):
        """Test returning fallback when alert_type differs."""
        mock_client = AsyncMock()
        advisor = PersonaFinancialAdvisor()
        advisor._client = mock_client

        invalid_response = AdvisorAlertResponse(
            alert_type="WINDFALL_DEPLETION",  # Different from fallback
            message="Safe message",
            suggested_action="Action",
        )
        with patch(
            "app.infrastructure.ai.cloud_vlm.advisor.generate_structured",
            return_value=invalid_response,
        ):
            fallback = AdvisorAlertResponse(
                alert_type="SAFE",
                message="Safe message",
                suggested_action="Safe action",
            )
            result = await advisor._warning(fallback, {}, "test persona")
            assert result == fallback

    @pytest.mark.asyncio
    async def test_truncates_message_to_two_sentences(self):
        """Test truncating message to two sentences."""
        mock_client = AsyncMock()
        advisor = PersonaFinancialAdvisor()
        advisor._client = mock_client

        response = AdvisorAlertResponse(
            alert_type="SAFE",
            message="First sentence. Second sentence. Third sentence.",
            suggested_action="Action one. Action two.",
        )
        with patch(
            "app.infrastructure.ai.cloud_vlm.advisor.generate_structured",
            return_value=response,
        ):
            fallback = AdvisorAlertResponse(
                alert_type="SAFE",
                message="Safe message",
                suggested_action="Safe action",
            )
            result = await advisor._warning(fallback, {}, "test persona")
            assert result.message == "First sentence. Second sentence."
            assert result.suggested_action == "Action one."


class TestGenerateFixedIncomeAlert:
    """Tests for generate_fixed_income_alert method."""

    @pytest.mark.asyncio
    async def test_returns_safe_when_no_alert(self):
        """Test returning SAFE when alert_flag is False."""
        advisor = PersonaFinancialAdvisor()
        advisor._client = None

        result = await advisor.generate_fixed_income_alert(
            current_balance=5000000.0,
            days_to_payday=10,
            trajectory=[{"date": "2024-01-01", "balance": 5000000.0}],
            alert_flag=False,
        )
        assert result.alert_type == "SAFE"
        assert "an toàn" in result.message
        assert result.suggested_action is None

    @pytest.mark.asyncio
    async def test_returns_cashflow_mismatch_when_alert(self):
        """Test returning CASHFLOW_MISMATCH when alert_flag is True."""
        advisor = PersonaFinancialAdvisor()
        advisor._client = None

        result = await advisor.generate_fixed_income_alert(
            current_balance=100000.0,
            days_to_payday=2,
            trajectory=[{"date": "2024-01-01", "balance": 500000.0}],
            alert_flag=True,
        )
        assert result.alert_type == "CASHFLOW_MISMATCH"
        assert "thiếu hụt" in result.message
        assert result.suggested_action is not None

    @pytest.mark.asyncio
    async def test_validates_current_balance(self):
        """Test validating current_balance."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(ValueError, match="current_balance must be finite"):
            await advisor.generate_fixed_income_alert(
                current_balance=float("nan"),
                days_to_payday=10,
                trajectory=[],
                alert_flag=False,
            )

    @pytest.mark.asyncio
    async def test_validates_days_to_payday(self):
        """Test validating days_to_payday."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(
            ValueError, match="days_to_payday must be a nonnegative integer"
        ):
            await advisor.generate_fixed_income_alert(
                current_balance=1000000.0,
                days_to_payday=-1,
                trajectory=[],
                alert_flag=False,
            )

    @pytest.mark.asyncio
    async def test_validates_alert_flag(self):
        """Test validating alert_flag."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(ValueError, match="alert_flag must be bool"):
            await advisor.generate_fixed_income_alert(
                current_balance=1000000.0,
                days_to_payday=10,
                trajectory=[],
                alert_flag="true",  # type: ignore
            )

    @pytest.mark.asyncio
    async def test_validates_trajectory_points(self):
        """Test validating trajectory points."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(
            ValueError, match="Each trajectory point must contain balance"
        ):
            await advisor.generate_fixed_income_alert(
                current_balance=1000000.0,
                days_to_payday=10,
                trajectory=[{"date": "2024-01-01"}],  # Missing balance
                alert_flag=False,
            )

    @pytest.mark.asyncio
    async def test_validates_trajectory_date_format(self):
        """Test validating trajectory date format."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(
            ValueError, match="Trajectory date must be an ISO date string"
        ):
            await advisor.generate_fixed_income_alert(
                current_balance=1000000.0,
                days_to_payday=10,
                trajectory=[{"date": 123, "balance": 1000000.0}],  # type: ignore
                alert_flag=False,
            )

    @pytest.mark.asyncio
    async def test_validates_trajectory_date_validity(self):
        """Test validating trajectory date exists."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(ValueError, match="day is out of range"):
            await advisor.generate_fixed_income_alert(
                current_balance=1000000.0,
                days_to_payday=10,
                trajectory=[
                    {"date": "2024-02-30", "balance": 1000000.0}
                ],  # Invalid date
                alert_flag=False,
            )


class TestGenerateFlexibleIncomeAlert:
    """Tests for generate_flexible_income_alert method."""

    @pytest.mark.asyncio
    async def test_returns_safe_when_no_alert(self):
        """Test returning SAFE when alert_flag is False."""
        advisor = PersonaFinancialAdvisor()
        advisor._client = None

        result = await advisor.generate_flexible_income_alert(
            current_balance=5000000.0,
            runway_days=30.0,
            safe_to_spend=100000.0,
            alert_flag=False,
        )
        assert result.alert_type == "SAFE"
        assert "an toàn" in result.message
        assert result.suggested_action is None

    @pytest.mark.asyncio
    async def test_returns_windfall_depletion_when_alert(self):
        """Test returning WINDFALL_DEPLETION when alert_flag is True."""
        advisor = PersonaFinancialAdvisor()
        advisor._client = None

        result = await advisor.generate_flexible_income_alert(
            current_balance=100000.0,
            runway_days=2.0,
            safe_to_spend=50000.0,
            alert_flag=True,
        )
        assert result.alert_type == "WINDFALL_DEPLETION"
        assert "tăng cao" in result.message
        assert "50.000" in result.message  # Formatted cap
        assert result.suggested_action is not None

    @pytest.mark.asyncio
    async def test_validates_runway_days(self):
        """Test validating runway_days."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(ValueError, match="runway_days must be nonnegative or None"):
            await advisor.generate_flexible_income_alert(
                current_balance=1000000.0,
                runway_days=-1.0,
                safe_to_spend=100000.0,
                alert_flag=False,
            )

    @pytest.mark.asyncio
    async def test_validates_safe_to_spend(self):
        """Test validating safe_to_spend."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(ValueError, match="safe_to_spend must be finite"):
            await advisor.generate_flexible_income_alert(
                current_balance=1000000.0,
                runway_days=30.0,
                safe_to_spend=float("nan"),
                alert_flag=False,
            )

    @pytest.mark.asyncio
    async def test_validates_alert_flag(self):
        """Test validating alert_flag."""
        advisor = PersonaFinancialAdvisor()
        with pytest.raises(ValueError, match="alert_flag must be bool"):
            await advisor.generate_flexible_income_alert(
                current_balance=1000000.0,
                runway_days=30.0,
                safe_to_spend=100000.0,
                alert_flag="true",  # type: ignore
            )


class TestPersonaFinancialAdvisorAclose:
    """Tests for aclose method."""

    @pytest.mark.asyncio
    async def test_closes_client_when_exists(self):
        """Test closing client when it exists."""
        mock_client = MagicMock()
        mock_client.aio.aclose = AsyncMock()
        advisor = PersonaFinancialAdvisor()
        advisor._client = mock_client
        advisor.is_mock = False

        await advisor.aclose()
        mock_client.aio.aclose.assert_awaited_once()
        mock_client.close.assert_called_once()

    @pytest.mark.asyncio
    async def test_no_op_when_no_client(self):
        """Test no-op when client is None."""
        advisor = PersonaFinancialAdvisor()
        advisor._client = None
        await advisor.aclose()  # Should not raise
