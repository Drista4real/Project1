"""Unit tests for forecaster features."""

from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from app.domain.interfaces.forecaster_interface import BalancePoint
from app.infrastructure.ai.forecaster.features import (
    FEATURE_NAMES,
    DailyCashflow,
    feature_vector,
    finite_amount,
    load_daily_cashflows,
    next_payday,
    validate_history,
)


class TestFiniteAmount:
    """Tests for finite_amount validator."""

    def test_valid_float(self) -> None:
        """Test valid float input."""
        assert finite_amount(100.5, "test") == 100.5

    def test_valid_int(self) -> None:
        """Test valid int input."""
        assert finite_amount(100, "test") == 100.0

    def test_valid_decimal(self) -> None:
        """Test valid Decimal input."""
        assert finite_amount(Decimal("100.5"), "test") == 100.5

    def test_valid_string_number(self) -> None:
        """Test valid numeric string input."""
        assert finite_amount("100.5", "test") == 100.5

    def test_reject_boolean(self) -> None:
        """Test that boolean is rejected."""
        with pytest.raises(ValueError, match="test must be a finite number"):
            finite_amount(True, "test")

    def test_reject_nan(self) -> None:
        """Test that NaN is rejected."""
        with pytest.raises(ValueError, match="test must be a finite number"):
            finite_amount(float("nan"), "test")

    def test_reject_infinity(self) -> None:
        """Test that infinity is rejected."""
        with pytest.raises(ValueError, match="test must be a finite number"):
            finite_amount(float("inf"), "test")

    def test_reject_negative_infinity(self) -> None:
        """Test that negative infinity is rejected."""
        with pytest.raises(ValueError, match="test must be a finite number"):
            finite_amount(float("-inf"), "test")

    def test_reject_non_numeric_string(self) -> None:
        """Test that non-numeric string is rejected."""
        with pytest.raises(ValueError, match="test must be a finite number"):
            finite_amount("not a number", "test")

    def test_reject_none(self) -> None:
        """Test that None is rejected."""
        with pytest.raises(ValueError, match="test must be a finite number"):
            finite_amount(None, "test")  # type: ignore


class TestDailyCashflow:
    """Tests for DailyCashflow dataclass."""

    def test_creation(self) -> None:
        """Test creating DailyCashflow."""
        day = date(2024, 1, 15)
        cashflow = DailyCashflow(day=day, income=1000.0, expense=500.0, balance=5000.0)
        assert cashflow.day == day
        assert cashflow.income == 1000.0
        assert cashflow.expense == 500.0
        assert cashflow.balance == 5000.0


class TestLoadDailyCashflows:
    """Tests for load_daily_cashflows function."""

    def test_load_valid_csv(self, tmp_path: Path) -> None:
        """Test loading valid CSV file."""
        csv_content = """date,income,expense,balance
2024-01-01,1000,500,5000
2024-01-02,0,200,4800
2024-01-03,500,100,5200
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        result = load_daily_cashflows(csv_path)

        assert len(result) == 3
        assert result[0].day == date(2024, 1, 1)
        assert result[0].income == 1000.0
        assert result[0].expense == 500.0
        assert result[0].balance == 5000.0
        assert result[-1].day == date(2024, 1, 3)

    def test_load_sorts_by_date(self, tmp_path: Path) -> None:
        """Test that CSV rows are sorted by date."""
        csv_content = """date,income,expense,balance
2024-01-03,500,100,5200
2024-01-01,1000,500,5000
2024-01-02,0,200,4800
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        result = load_daily_cashflows(csv_path)

        assert result[0].day == date(2024, 1, 1)
        assert result[1].day == date(2024, 1, 2)
        assert result[2].day == date(2024, 1, 3)

    def test_reject_missing_file(self, tmp_path: Path) -> None:
        """Test that missing file raises FileNotFoundError."""
        with pytest.raises(FileNotFoundError, match="Missing daily cashflow CSV"):
            load_daily_cashflows(tmp_path / "missing.csv")

    def test_reject_wrong_columns(self, tmp_path: Path) -> None:
        """Test that wrong columns raise ValueError."""
        csv_content = """date,income,expense
2024-01-01,1000,500
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(
            ValueError, match="CSV requires date,income,expense,balance columns"
        ):
            load_daily_cashflows(csv_path)

    def test_reject_extra_columns(self, tmp_path: Path) -> None:
        """Test that extra columns raise ValueError."""
        csv_content = """date,income,expense,balance,extra
2024-01-01,1000,500,5000,foo
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(
            ValueError, match="CSV requires date,income,expense,balance columns"
        ):
            load_daily_cashflows(csv_path)

    def test_reject_invalid_date(self, tmp_path: Path) -> None:
        """Test that invalid date raises ValueError."""
        csv_content = """date,income,expense,balance
not-a-date,1000,500,5000
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(ValueError, match="Invalid daily cashflow"):
            load_daily_cashflows(csv_path)

    def test_reject_negative_income(self, tmp_path: Path) -> None:
        """Test that negative income raises ValueError."""
        csv_content = """date,income,expense,balance
2024-01-01,-100,500,5000
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(ValueError, match="Income and expense must be nonnegative"):
            load_daily_cashflows(csv_path)

    def test_reject_negative_expense(self, tmp_path: Path) -> None:
        """Test that negative expense raises ValueError."""
        csv_content = """date,income,expense,balance
2024-01-01,1000,-500,5000
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(ValueError, match="Income and expense must be nonnegative"):
            load_daily_cashflows(csv_path)

    def test_reject_non_consecutive_dates(self, tmp_path: Path) -> None:
        """Test that non-consecutive dates raise ValueError."""
        csv_content = """date,income,expense,balance
2024-01-01,1000,500,5000
2024-01-03,0,200,4800
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(
            ValueError, match="Cashflow dates must be unique and consecutive"
        ):
            load_daily_cashflows(csv_path)

    def test_reject_duplicate_dates(self, tmp_path: Path) -> None:
        """Test that duplicate dates raise ValueError."""
        csv_content = """date,income,expense,balance
2024-01-01,1000,500,5000
2024-01-01,0,200,4800
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(
            ValueError, match="Cashflow dates must be unique and consecutive"
        ):
            load_daily_cashflows(csv_path)

    def test_reject_empty_csv(self, tmp_path: Path) -> None:
        """Test that empty CSV raises ValueError."""
        csv_content = """date,income,expense,balance
"""
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        with pytest.raises(ValueError, match="Daily cashflow CSV must not be empty"):
            load_daily_cashflows(csv_path)


class TestValidateHistory:
    """Tests for validate_history function."""

    def test_valid_history(self) -> None:
        """Test valid history passes validation."""
        history = [
            BalancePoint(date(2024, 1, 1), Decimal("5000")),
            BalancePoint(date(2024, 1, 2), Decimal("4800")),
            BalancePoint(date(2024, 1, 3), Decimal("5200")),
        ]
        validate_history(history, minimum=3)

    def test_valid_history_default_minimum(self) -> None:
        """Test valid history with default minimum."""
        history = [BalancePoint(date(2024, 1, 1), Decimal("5000"))]
        validate_history(history)

    def test_reject_insufficient_history(self) -> None:
        """Test that insufficient history raises ValueError."""
        history = [BalancePoint(date(2024, 1, 1), Decimal("5000"))]
        with pytest.raises(
            ValueError, match="At least 8 consecutive daily balance points"
        ):
            validate_history(history, minimum=8)

    def test_reject_non_finite_balance(self) -> None:
        """Test that non-finite balance raises ValueError."""
        history = [
            BalancePoint(date(2024, 1, 1), Decimal("5000")),
            BalancePoint(date(2024, 1, 2), Decimal("NaN")),
        ]
        with pytest.raises(ValueError, match="balance must be a finite number"):
            validate_history(history)

    def test_reject_non_date(self) -> None:
        """Test that non-date day raises ValueError."""
        history = [
            BalancePoint(date(2024, 1, 1), Decimal("5000")),
            BalancePoint("2024-01-02", Decimal("4800")),  # type: ignore
        ]
        with pytest.raises(ValueError, match="History dates must be date instances"):
            validate_history(history)

    def test_reject_non_consecutive_dates(self) -> None:
        """Test that non-consecutive dates raise ValueError."""
        history = [
            BalancePoint(date(2024, 1, 1), Decimal("5000")),
            BalancePoint(date(2024, 1, 3), Decimal("4800")),
        ]
        with pytest.raises(
            ValueError, match="History must contain consecutive daily dates"
        ):
            validate_history(history)

    def test_reject_out_of_order_dates(self) -> None:
        """Test that out-of-order dates raise ValueError."""
        history = [
            BalancePoint(date(2024, 1, 2), Decimal("4800")),
            BalancePoint(date(2024, 1, 1), Decimal("5000")),
        ]
        with pytest.raises(
            ValueError, match="History must contain consecutive daily dates"
        ):
            validate_history(history)


class TestFeatureVector:
    """Tests for feature_vector function."""

    def test_payday_5th(self) -> None:
        """Test payday feature on 5th of month."""
        day = date(2024, 1, 5)
        vector = feature_vector(day, 100.0, 50.0)
        assert vector[0] == 1  # is_payday
        assert vector[3] == 5  # day_of_month

    def test_payday_30th(self) -> None:
        """Test payday feature on 30th of month (rent day)."""
        day = date(2024, 1, 30)
        vector = feature_vector(day, 100.0, 50.0)
        assert vector[1] == 1  # is_rent_day
        assert vector[3] == 30  # day_of_month

    def test_weekend(self) -> None:
        """Test weekend feature."""
        # 2024-01-06 is Saturday
        day = date(2024, 1, 6)
        vector = feature_vector(day, 100.0, 50.0)
        assert vector[2] == 1  # is_weekend

    def test_weekday(self) -> None:
        """Test weekday feature."""
        # 2024-01-08 is Monday
        day = date(2024, 1, 8)
        vector = feature_vector(day, 100.0, 50.0)
        assert vector[2] == 0  # not weekend

    def test_lag_features(self) -> None:
        """Test lag features are correctly set."""
        day = date(2024, 1, 10)
        vector = feature_vector(day, 123.45, 67.89)
        assert vector[4] == 123.45  # delta_lag_1
        assert vector[5] == 67.89  # delta_lag_7

    def test_lag_validates_finite(self) -> None:
        """Test that lag features validate finite amounts."""
        day = date(2024, 1, 10)
        with pytest.raises(ValueError, match="delta_lag_1 must be a finite number"):
            feature_vector(day, float("nan"), 50.0)

    def test_feature_names_match(self) -> None:
        """Test that feature vector length matches FEATURE_NAMES."""
        day = date(2024, 1, 10)
        vector = feature_vector(day, 100.0, 50.0)
        assert len(vector) == len(FEATURE_NAMES)
        assert vector.dtype == "float64"


class TestNextPayday:
    """Tests for next_payday function."""

    def test_before_5th(self) -> None:
        """Test next payday when before 5th."""
        as_of = date(2024, 1, 3)
        payday = next_payday(as_of)
        assert payday == date(2024, 1, 5)

    def test_on_5th(self) -> None:
        """Test next payday when on 5th (should be next month)."""
        as_of = date(2024, 1, 5)
        payday = next_payday(as_of)
        assert payday == date(2024, 2, 5)

    def test_after_5th(self) -> None:
        """Test next payday when after 5th."""
        as_of = date(2024, 1, 10)
        payday = next_payday(as_of)
        assert payday == date(2024, 2, 5)

    def test_year_rollover(self) -> None:
        """Test next payday handles year rollover."""
        as_of = date(2024, 12, 20)
        payday = next_payday(as_of)
        assert payday == date(2025, 1, 5)

    def test_february_handling(self) -> None:
        """Test next payday handles February correctly."""
        as_of = date(2024, 1, 20)
        payday = next_payday(as_of)
        assert payday == date(2024, 2, 5)
