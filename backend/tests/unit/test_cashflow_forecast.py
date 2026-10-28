"""Tests for cashflow_forecast use case."""

from datetime import date
from decimal import Decimal
from unittest.mock import Mock

import pytest

from app.application.use_cases.cashflow_forecast import ForecastCashflow
from app.domain.interfaces.forecaster_interface import (
    BalancePoint,
    CashflowForecast,
    ICashflowForecaster,
)


class TestForecastCashflow:
    """Tests for ForecastCashflow use case."""

    def setup_method(self):
        self.mock_fixed = Mock(spec=ICashflowForecaster)
        self.mock_flexible = Mock(spec=ICashflowForecaster)
        self.use_case = ForecastCashflow(
            fixed=self.mock_fixed, flexible=self.mock_flexible
        )

    def test_execute_fixed_income(self):
        """Test execute with fixed income type."""
        history = [
            BalancePoint(day=date(2024, 1, 1), balance=Decimal("1000000")),
            BalancePoint(day=date(2024, 1, 2), balance=Decimal("900000")),
        ]
        expected_forecast = CashflowForecast(
            balances=(BalancePoint(day=date(2024, 1, 3), balance=Decimal("850000")),),
            runway_days=30.0,
            alert_flag=False,
        )
        self.mock_fixed.forecast.return_value = expected_forecast

        result = self.use_case.execute(history, income_type="fixed", horizon_days=30)

        assert result == expected_forecast
        self.mock_fixed.forecast.assert_called_once_with(history, 30)
        self.mock_flexible.forecast.assert_not_called()

    def test_execute_flexible_income(self):
        """Test execute with flexible income type."""
        history = [
            BalancePoint(day=date(2024, 1, 1), balance=Decimal("1000000")),
        ]
        expected_forecast = CashflowForecast(
            balances=(BalancePoint(day=date(2024, 1, 2), balance=Decimal("950000")),),
            runway_days=25.0,
            alert_flag=False,
        )
        self.mock_flexible.forecast.return_value = expected_forecast

        result = self.use_case.execute(history, income_type="flexible", horizon_days=30)

        assert result == expected_forecast
        self.mock_flexible.forecast.assert_called_once_with(history, 30)
        self.mock_fixed.forecast.assert_not_called()

    def test_execute_default_horizon(self):
        """Test execute with default horizon_days."""
        history = [BalancePoint(day=date(2024, 1, 1), balance=Decimal("1000000"))]
        expected_forecast = CashflowForecast(
            balances=(BalancePoint(day=date(2024, 1, 2), balance=Decimal("950000")),),
            runway_days=30.0,
            alert_flag=False,
        )
        self.mock_fixed.forecast.return_value = expected_forecast

        result = self.use_case.execute(history, income_type="fixed")

        assert result == expected_forecast
        self.mock_fixed.forecast.assert_called_once_with(history, 30)

    def test_execute_empty_history_raises(self):
        """Test execute raises ValueError for empty history."""
        with pytest.raises(
            ValueError, match="Provide balance history and a positive forecast horizon"
        ):
            self.use_case.execute([], income_type="fixed", horizon_days=30)

    def test_execute_zero_horizon_raises(self):
        """Test execute raises ValueError for zero horizon."""
        history = [BalancePoint(day=date(2024, 1, 1), balance=Decimal("1000000"))]
        with pytest.raises(
            ValueError, match="Provide balance history and a positive forecast horizon"
        ):
            self.use_case.execute(history, income_type="fixed", horizon_days=0)

    def test_execute_negative_horizon_raises(self):
        """Test execute raises ValueError for negative horizon."""
        history = [BalancePoint(day=date(2024, 1, 1), balance=Decimal("1000000"))]
        with pytest.raises(
            ValueError, match="Provide balance history and a positive forecast horizon"
        ):
            self.use_case.execute(history, income_type="fixed", horizon_days=-1)

    def test_execute_invalid_income_type_raises(self):
        """Test execute raises ValueError for invalid income type."""
        history = [BalancePoint(day=date(2024, 1, 1), balance=Decimal("1000000"))]
        with pytest.raises(ValueError, match="Unsupported income type"):
            self.use_case.execute(history, income_type="invalid", horizon_days=30)

    def test_execute_case_sensitive_income_type(self):
        """Test that income_type is case sensitive."""
        history = [BalancePoint(day=date(2024, 1, 1), balance=Decimal("1000000"))]
        with pytest.raises(ValueError, match="Unsupported income type"):
            self.use_case.execute(history, income_type="FIXED", horizon_days=30)
        with pytest.raises(ValueError, match="Unsupported income type"):
            self.use_case.execute(history, income_type="FLEXIBLE", horizon_days=30)
