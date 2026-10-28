"""Unit tests for flexible income forecaster."""

from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

import pytest

from app.domain.interfaces.forecaster_interface import BalancePoint, CashflowForecast
from app.infrastructure.ai.forecaster.flexible_income import (
    FlexibleIncomeForecaster,
    calculate_runway,
    ewma_burn_rate,
)


class TestEwmaBurnRate:
    """Tests for ewma_burn_rate function."""

    def test_single_expense(self) -> None:
        """Test EWMA with single expense returns that expense."""
        expenses = [100000.0]
        burn = ewma_burn_rate(expenses, alpha=0.3)
        assert burn == 100000.0

    def test_two_expenses(self) -> None:
        """Test EWMA with two expenses."""
        expenses = [100000.0, 200000.0]
        # burn = 0.3 * 200000 + 0.7 * 100000 = 60000 + 70000 = 130000
        burn = ewma_burn_rate(expenses, alpha=0.3)
        assert burn == 130000.0

    def test_multiple_expenses(self) -> None:
        """Test EWMA with multiple expenses."""
        expenses = [100000.0, 200000.0, 150000.0, 300000.0]
        burn = ewma_burn_rate(expenses, alpha=0.3)
        # burn_0 = 100000
        # burn_1 = 0.3*200000 + 0.7*100000 = 130000
        # burn_2 = 0.3*150000 + 0.7*130000 = 45000 + 91000 = 136000
        # burn_3 = 0.3*300000 + 0.7*136000 = 90000 + 95200 = 185200
        assert burn == 185200.0

    def test_alpha_one(self) -> None:
        """Test EWMA with alpha=1 (no smoothing)."""
        expenses = [100000.0, 200000.0, 300000.0]
        burn = ewma_burn_rate(expenses, alpha=1.0)
        assert burn == 300000.0  # Last expense

    def test_alpha_small(self) -> None:
        """Test EWMA with small alpha (heavy smoothing)."""
        expenses = [100000.0, 200000.0, 300000.0]
        burn = ewma_burn_rate(expenses, alpha=0.01)
        # With alpha=0.01, after 3 iterations burn ~ 102990 (close to first expense)
        assert abs(burn - 100000.0) < 3000

    def test_reject_invalid_alpha_type(self) -> None:
        """Test that non-numeric alpha is rejected."""
        with pytest.raises(ValueError, match="alpha must be a finite number"):
            ewma_burn_rate([100000.0], alpha="not a number")  # type: ignore

    def test_reject_alpha_zero(self) -> None:
        """Test that alpha <= 0 is rejected."""
        with pytest.raises(ValueError, match="alpha must be in"):
            ewma_burn_rate([100000.0], alpha=0)

    def test_reject_alpha_negative(self) -> None:
        """Test that negative alpha is rejected."""
        with pytest.raises(ValueError, match="alpha must be in"):
            ewma_burn_rate([100000.0], alpha=-0.1)

    def test_reject_alpha_greater_than_one(self) -> None:
        """Test that alpha > 1 is rejected."""
        with pytest.raises(ValueError, match="alpha must be in"):
            ewma_burn_rate([100000.0], alpha=1.5)

    def test_reject_nan_alpha(self) -> None:
        """Test that NaN alpha is rejected."""
        with pytest.raises(ValueError, match="alpha must be a finite number"):
            ewma_burn_rate([100000.0], alpha=float("nan"))

    def test_reject_non_numeric_expense(self) -> None:
        """Test that non-numeric expense is rejected."""
        with pytest.raises(ValueError, match="expense must be a finite number"):
            ewma_burn_rate(["not a number"], alpha=0.3)

    def test_reject_negative_expense(self) -> None:
        """Test that negative expense is rejected."""
        with pytest.raises(ValueError, match="Expenses must be nonnegative"):
            ewma_burn_rate([100000.0, -50000.0], alpha=0.3)

    def test_reject_nan_expense(self) -> None:
        """Test that NaN expense is rejected."""
        with pytest.raises(ValueError, match="expense must be a finite number"):
            ewma_burn_rate([100000.0, float("nan")], alpha=0.3)


class TestCalculateRunway:
    """Tests for calculate_runway and _calculate functions."""

    def test_calculate_runway_positive_burn(self) -> None:
        """Test runway calculation with positive burn rate."""
        current_balance = 3000000.0
        expenses = [100000.0] * 30
        result = calculate_runway(current_balance, expenses)

        assert isinstance(result, dict)
        assert "runway_days" in result
        assert "safe_to_spend" in result
        assert "trajectory_30d" in result
        assert "alert_flag" in result
        assert "alert_type" in result
        assert "burn_rate_daily" in result

        # With constant 100k daily, burn rate = 100k, runway = 30 days
        assert result["burn_rate_daily"] == 100000.0
        assert result["runway_days"] == 30.0
        assert result["safe_to_spend"] == 100000.0

    def test_calculate_runway_zero_burn(self) -> None:
        """Test runway calculation with zero burn rate."""
        current_balance = 3000000.0
        expenses = [0.0] * 30
        result = calculate_runway(current_balance, expenses)

        assert result["burn_rate_daily"] == 0.0
        assert result["runway_days"] is None  # Unbounded
        assert result["safe_to_spend"] == 100000.0

    def test_calculate_runway_zero_balance_zero_burn(self) -> None:
        """Test runway with zero balance and zero burn."""
        current_balance = 0.0
        expenses = [0.0] * 30
        result = calculate_runway(current_balance, expenses)

        assert result["runway_days"] == 0.0  # 0/0 = 0 in this case

    def test_calculate_runway_negative_balance(self) -> None:
        """Test runway with negative balance."""
        current_balance = -100000.0
        expenses = [100000.0] * 30
        result = calculate_runway(current_balance, expenses)

        assert result["runway_days"] == 0.0  # max(-100000, 0) / 100000 = 0

    def test_calculate_runway_spike_detection(self) -> None:
        """Test spike detection in recent spending."""
        # Baseline: 100k/day for 27 days
        # Recent: 200k/day for 3 days (2x baseline > 1.3x)
        expenses = [100000.0] * 27 + [200000.0, 200000.0, 200000.0]
        current_balance = 3000000.0
        result = calculate_runway(current_balance, expenses)

        assert result["alert_flag"] is True
        assert result["alert_type"] == "WINDFALL_DEPLETION"

    def test_calculate_runway_no_spike(self) -> None:
        """Test no spike when recent spending is normal."""
        expenses = [100000.0] * 30
        current_balance = 3000000.0
        result = calculate_runway(current_balance, expenses)

        assert result["alert_flag"] is False
        assert result["alert_type"] is None

    def test_calculate_runway_low_runway_alert(self) -> None:
        """Test alert when runway <= 7 days."""
        current_balance = 500000.0  # 5 days at 100k/day
        expenses = [100000.0] * 30
        result = calculate_runway(current_balance, expenses)

        assert result["runway_days"] == 5.0
        assert result["alert_flag"] is True
        assert result["alert_type"] == "WINDFALL_DEPLETION"

    def test_calculate_runway_trajectory(self) -> None:
        """Test trajectory_30d calculation."""
        current_balance = 3000000.0
        expenses = [100000.0] * 30
        result = calculate_runway(current_balance, expenses)

        assert len(result["trajectory_30d"]) == 30
        assert result["trajectory_30d"][0] == 2900000.0  # Day 1
        assert result["trajectory_30d"][29] == 0.0  # Day 30

    def test_calculate_runway_insufficient_expenses(self) -> None:
        """Test calculate_runway with fewer than 4 expenses (no spike check)."""
        current_balance = 3000000.0
        expenses = [100000.0, 100000.0, 100000.0]  # Only 3
        result = calculate_runway(current_balance, expenses)

        # Should not crash, just no spike detection
        assert "burn_rate_daily" in result
        assert result["alert_flag"] is False

    def test_calculate_runway_empty_expenses(self) -> None:
        """Test calculate_runway with empty expenses."""
        current_balance = 3000000.0
        expenses: list[float] = []
        result = calculate_runway(current_balance, expenses)

        assert (
            result["burn_rate_daily"] == 0.0
        )  # First expense initializes, but list is empty


class TestFlexibleIncomeForecasterInit:
    """Tests for FlexibleIncomeForecaster initialization."""

    def test_init_default_alpha(self) -> None:
        """Test initialization with default alpha."""
        forecaster = FlexibleIncomeForecaster()
        assert forecaster.alpha == 0.3

    def test_init_custom_alpha(self) -> None:
        """Test initialization with custom alpha."""
        forecaster = FlexibleIncomeForecaster(alpha=0.5)
        assert forecaster.alpha == 0.5

    def test_init_invalid_alpha(self) -> None:
        """Test initialization fails with invalid alpha."""
        with pytest.raises(ValueError, match="alpha must be in"):
            FlexibleIncomeForecaster(alpha=1.5)

    def test_init_custom_data_path(self, tmp_path: Path) -> None:
        """Test initialization with custom data path."""
        data_path = tmp_path / "custom.csv"
        forecaster = FlexibleIncomeForecaster(data_path=data_path)
        assert forecaster.data_path == data_path


class TestFlexibleIncomeForecasterLoadExpenses:
    """Tests for FlexibleIncomeForecaster.load_expenses method."""

    @pytest.fixture
    def forecaster(self, tmp_path: Path):
        """Create forecaster with test CSV data."""
        csv_content = "date,income,expense,balance\n"
        base_date = date(2024, 1, 1)
        for i in range(30):
            csv_content += (
                f"{base_date + timedelta(days=i)},1000,"
                f"{100000 + i * 1000},{5000000 - i * 50000}\n"
            )
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        return FlexibleIncomeForecaster(data_path=csv_path)

    def test_load_expenses_all(self, forecaster):
        """Test loading all expenses."""
        expenses = forecaster.load_expenses()
        assert len(expenses) == 30
        assert expenses[0] == 100000.0
        assert expenses[-1] == 129000.0

    def test_load_expenses_with_as_of(self, forecaster):
        """Test loading expenses up to as_of date."""
        as_of = date(2024, 1, 15)
        expenses = forecaster.load_expenses(as_of=as_of)
        assert len(expenses) == 15
        assert expenses[-1] == 114000.0

    def test_load_expenses_as_of_not_in_data(self, forecaster):
        """Test loading expenses when as_of not in data raises error."""
        as_of = date(2024, 2, 1)  # After data ends
        with pytest.raises(
            ValueError, match="Expense history must contain the forecast's as-of date"
        ):
            forecaster.load_expenses(as_of=as_of)

    def test_load_expenses_empty_after_filter(self, forecaster):
        """Test loading expenses when filter removes all data."""
        as_of = date(2023, 12, 31)  # Before data starts
        with pytest.raises(
            ValueError, match="Expense history must contain the forecast's as-of date"
        ):
            forecaster.load_expenses(as_of=as_of)


class TestFlexibleIncomeForecasterCalculateRunway:
    """Tests for FlexibleIncomeForecaster.calculate_runway method."""

    def test_calculate_runway_delegates(self) -> None:
        """Test calculate_runway uses forecaster's alpha."""
        forecaster = FlexibleIncomeForecaster(alpha=0.5)
        result = forecaster.calculate_runway(3000000.0, [100000.0, 200000.0])

        assert result["burn_rate_daily"] == 150000.0
        assert result["runway_days"] == 20.0


class TestFlexibleIncomeForecasterForecast:
    """Tests for FlexibleIncomeForecaster.forecast method."""

    @pytest.fixture
    def forecaster(self, tmp_path: Path):
        """Create forecaster with test CSV data."""
        csv_content = "date,income,expense,balance\n"
        base_date = date(2024, 1, 1)
        for i in range(30):
            csv_content += (
                f"{base_date + timedelta(days=i)},1000,"
                f"{100000 + i * 1000},{5000000 - i * 50000}\n"
            )
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        return FlexibleIncomeForecaster(data_path=csv_path)

    @pytest.fixture
    def valid_history(self):
        """Create valid history."""
        base_date = date(2024, 1, 15)
        return [
            BalancePoint(
                base_date + timedelta(days=i), Decimal(str(5000000 - i * 50000))
            )
            for i in range(10)
        ]

    def test_forecast_valid(self, forecaster, valid_history):
        """Test forecast with valid input."""
        result = forecaster.forecast(valid_history, horizon_days=30)

        assert isinstance(result, CashflowForecast)
        assert len(result.balances) == 30
        assert result.runway_days is not None or result.runway_days == 0.0
        assert isinstance(result.alert_flag, bool)
        assert result.alert_type in (None, "WINDFALL_DEPLETION")
        assert result.safe_to_spend > 0

    def test_forecast_invalid_horizon_type(self, forecaster, valid_history):
        """Test forecast fails with non-int horizon_days."""
        with pytest.raises(ValueError, match="horizon_days must be an integer"):
            forecaster.forecast(valid_history, horizon_days=30.0)  # type: ignore

    def test_forecast_horizon_too_small(self, forecaster, valid_history):
        """Test forecast fails with horizon_days < 1."""
        with pytest.raises(ValueError, match="horizon_days must be an integer in"):
            forecaster.forecast(valid_history, horizon_days=0)

    def test_forecast_horizon_too_large(self, forecaster, valid_history):
        """Test forecast fails with horizon_days > 365."""
        with pytest.raises(ValueError, match="horizon_days must be an integer in"):
            forecaster.forecast(valid_history, horizon_days=366)

    def test_forecast_uses_load_expenses(self, forecaster, valid_history):
        """Test forecast uses load_expenses internally."""
        as_of = valid_history[-1].day
        with patch.object(
            forecaster, "load_expenses", return_value=[100000.0] * 30
        ) as mock_load:
            forecaster.forecast(valid_history, horizon_days=30)
            mock_load.assert_called_once_with(as_of)
