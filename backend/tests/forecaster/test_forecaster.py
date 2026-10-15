"""Causal forecast and financial-rule tests with real LightGBM checkpoints."""

import csv
import pickle
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from unittest.mock import Mock

import numpy as np
import pytest

from app.domain.interfaces.forecaster_interface import BalancePoint
from app.infrastructure.ai.forecaster.features import (
    DailyCashflow,
    feature_vector,
    load_daily_cashflows,
    next_payday,
)
from app.infrastructure.ai.forecaster.fixed_income import FixedIncomeForecaster
from app.infrastructure.ai.forecaster.flexible_income import (
    FlexibleIncomeForecaster,
    calculate_runway,
    ewma_burn_rate,
)
from scripts.generate_synthetic_data import generate_balances
from scripts.train_forecaster import build_features, report_metrics, train


def write_data(path: Path, days: int = 90) -> None:
    """Write deterministic daily observations with payroll and rent shocks."""
    balance = 10_000_000.0
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["date", "income", "expense", "balance"])
        for offset in range(days):
            day = date(2026, 1, 1) + timedelta(days=offset)
            income = 15_000_000 if day.day == 5 else 0
            expense = 3_000_000 if day.day == 30 else 200_000
            balance += income - expense
            writer.writerow([day.isoformat(), income, expense, balance])


@pytest.fixture
def fixed(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> FixedIncomeForecaster:
    """Train on temporary data and validate the emitted chronological metrics."""
    data = tmp_path / "balance_fixed.csv"
    write_data(data)
    train(data, tmp_path)
    output = capsys.readouterr().out
    assert "66 train / 17 test" in output
    assert "One-day-ahead: MAE=" in output
    assert "Autoregressive holdout: MAE=" in output
    assert "MAPE=" in output
    return FixedIncomeForecaster(tmp_path / "lgbm_forecaster.pkl", data_path=data)


def history(as_of: date, balance: float = 1_000_000) -> list[BalancePoint]:
    """Provide eight balances so seven observed daily deltas are available."""
    return [
        BalancePoint(as_of - timedelta(days=7 - i), Decimal(str(balance + i)))
        for i in range(8)
    ]


def test_features_have_only_past_balances() -> None:
    """Check exact lags, feature order, calendar flags, and discarded warm-up."""
    rows = [
        DailyCashflow(date(2026, 1, 1) + timedelta(days=i), 9e9, 8e9, float(i))
        for i in range(15)
    ]
    features, targets = build_features(rows)
    assert features.shape == (8, 6)
    assert features[0].tolist() == [0, 0, 0, 8, 1, 0]
    assert targets.tolist() == [1] * 8
    assert feature_vector(date(2026, 9, 5), 100, 200).tolist() == [1, 0, 1, 5, 100, 200]
    assert feature_vector(date(2026, 9, 30), 100, 200)[1] == 1


def test_autoregressive_lags_and_dates(fixed: FixedIncomeForecaster) -> None:
    """Lag 1 changes immediately; lag 7 consumes the first prediction on day 8."""
    vectors: list[np.ndarray] = []

    def predict(features: np.ndarray, *, num_threads: int) -> np.ndarray:
        """Return distinguishable values so lag reuse is observable."""
        assert num_threads == 1
        vectors.append(features.copy())
        return np.asarray([2_000_000 + len(vectors)])

    fixed.model.booster_.predict = Mock(side_effect=predict)
    observed = history(date(2026, 1, 31))
    result = fixed.forecast(observed)
    assert len(result.balances) == 30
    assert result.balances[0].day == date(2026, 2, 1)
    assert result.balances[-1].day == date(2026, 3, 2)
    assert vectors[0][0, 4:].tolist() == [1, 1]
    assert vectors[1][0, 4] == 2_000_001
    assert vectors[7][0, 5] == 2_000_001
    assert result.balances[0].balance == Decimal(1_000_007 + 2_000_001)
    assert result.balances[1].balance == Decimal(1_000_007 + 2_000_001 + 2_000_002)
    assert result.countdown_to_payday == 5


@pytest.mark.parametrize(("low_day", "alert"), [(1, True), (3, False)])
def test_alert_excludes_payday(
    fixed: FixedIncomeForecaster, low_day: int, alert: bool
) -> None:
    """Below-threshold predictions alert only strictly before the next salary."""
    calls = 0
    current = 1_000_007

    def predict(features: np.ndarray, *, num_threads: int) -> np.ndarray:
        """Force a low prediction on exactly one forecast day."""
        nonlocal calls, current
        calls += 1
        target = 499_999 if calls == low_day else 500_000
        delta = target - current
        current = target
        return np.asarray([delta])

    fixed.model.booster_.predict = Mock(side_effect=predict)
    result = fixed.forecast(history(date(2026, 1, 2)))
    assert result.alert_flag is alert
    assert result.alert_type == ("CASHFLOW_MISMATCH" if alert else None)


@pytest.mark.parametrize(
    ("as_of", "expected"),
    [
        (date(2026, 12, 31), date(2027, 1, 5)),
        (date(2026, 2, 5), date(2026, 3, 5)),
        (date(2028, 2, 29), date(2028, 3, 5)),
    ],
)
def test_payday_rollover(as_of: date, expected: date) -> None:
    """Payday calculations handle same-day salary, new years, and leap years."""
    assert next_payday(as_of) == expected


def test_fixed_json_wrapper(fixed: FixedIncomeForecaster) -> None:
    """The wrapper initializes lags from history and uses the supplied balance."""
    result = fixed.forecast_30_days(400_000, date(2026, 3, 31))
    assert len(result["trajectory"]) == 30
    assert result["trajectory"][0]["date"] == "2026-04-01"
    assert result["countdown_to_payday"] == 5
    assert result["alert_type"] == "CASHFLOW_MISMATCH"
    with pytest.raises(ValueError, match="end on start_date"):
        fixed.forecast_30_days(1_000_000, date(2026, 4, 1))


def test_ewma_and_runway() -> None:
    """EWMA initializes at the first expense; runway and depletion follow formulas."""
    assert ewma_burn_rate([100, 200, 300]) == pytest.approx(181)
    result = calculate_runway(1810, [100, 200, 300])
    assert result["runway_days"] == pytest.approx(10)
    assert result["safe_to_spend"] == pytest.approx(1810 / 30)
    assert result["trajectory_30d"][0] == pytest.approx(1629)
    assert result["trajectory_30d"][-1] == pytest.approx(1810 - 181 * 30)
    assert not result["alert_flag"]


@pytest.mark.parametrize("expenses", [[], [0, 0, 0]])
def test_zero_burn_is_json_safe(expenses: list[float]) -> None:
    """No spend yields unbounded runway without NaN or infinity."""
    result = calculate_runway(1000, expenses)
    assert result["runway_days"] is None
    assert result["trajectory_30d"] == [1000] * 30
    assert not result["alert_flag"]
    assert calculate_runway(0, expenses)["alert_flag"]


@pytest.mark.parametrize(
    ("expenses", "alert"),
    [
        ([100] * 7 + [130] * 3, False),
        ([100] * 7 + [131] * 3, True),
        ([0] * 7 + [1] * 3, True),
    ],
)
def test_spending_spike(expenses: list[float], alert: bool) -> None:
    """Compare the recent three-day mean to the independent earlier baseline."""
    assert calculate_runway(1_000_000, expenses)["alert_flag"] is alert


def test_runway_boundary() -> None:
    """Seven days remaining alerts inclusively, even without a spending spike."""
    assert calculate_runway(700, [100])["alert_type"] == "WINDFALL_DEPLETION"
    assert not calculate_runway(701, [100])["alert_flag"]


@pytest.mark.parametrize("expenses", [[-1], [float("nan")], [float("inf")]])
def test_invalid_expenses(expenses: list[float]) -> None:
    """Reject invalid daily amounts before generating forecast metrics."""
    with pytest.raises(ValueError):
        calculate_runway(1000, expenses)


def test_flexible_csv_forecast(tmp_path: Path) -> None:
    """Exclude future expenses and return the domain result with alerts and dates."""
    path = tmp_path / "balance_flexible.csv"
    write_data(path)
    forecaster = FlexibleIncomeForecaster(data_path=path)
    assert len(forecaster.load_expenses(date(2026, 1, 4))) == 4
    result = forecaster.forecast(history(date(2026, 1, 4)), horizon_days=10)
    assert len(result.balances) == 10
    assert result.balances[0].day == date(2026, 1, 5)
    assert result.runway_days == pytest.approx(1_000_007 / 200_000)
    assert result.alert_type == "WINDFALL_DEPLETION"


def test_missing_files(tmp_path: Path) -> None:
    """All file-dependent entry points explain missing inputs."""
    path = tmp_path / "missing.csv"
    with pytest.raises(FileNotFoundError, match="Missing daily cashflow CSV"):
        train(path, tmp_path)
    with pytest.raises(FileNotFoundError, match="Missing forecaster checkpoint"):
        FixedIncomeForecaster(tmp_path / "missing.pkl")
    with pytest.raises(FileNotFoundError, match="Missing daily cashflow CSV"):
        FlexibleIncomeForecaster(data_path=path).load_expenses()


def test_nonconsecutive_csv(tmp_path: Path) -> None:
    """Calendar lags cannot silently treat missing days as adjacent observations."""
    path = tmp_path / "bad.csv"
    path.write_text(
        "date,income,expense,balance\n2026-01-01,0,10,100\n2026-01-03,0,10,90\n"
    )
    with pytest.raises(ValueError, match="consecutive"):
        load_daily_cashflows(path)


def test_zero_target_mape(capsys: pytest.CaptureFixture[str]) -> None:
    """Zero targets produce an explicit undefined MAPE rather than division by zero."""
    report_metrics(np.zeros(2), np.ones(2), "test")
    assert "MAPE=undefined" in capsys.readouterr().out


def test_reject_raw_balance_checkpoint(
    fixed: FixedIncomeForecaster, tmp_path: Path
) -> None:
    """Prevent a raw-balance model from being interpreted as a daily delta."""
    fixed.model.forecaster_target_ = "balance"
    path = tmp_path / "raw-model.pkl"
    with path.open("wb") as stream:
        pickle.dump(fixed.model, stream)
    with pytest.raises(ValueError, match="delta pipeline"):
        FixedIncomeForecaster(path)


def test_delta_requires_eight_balances(fixed: FixedIncomeForecaster) -> None:
    """Lag 7 of a difference needs eight historical balances, not seven."""
    with pytest.raises(ValueError, match="At least 8"):
        fixed.forecast(history(date(2026, 1, 31))[1:])


def test_180_day_holdout_meets_targets(tmp_path: Path) -> None:
    """Evaluate the actual inference adapter on a strictly unseen 30-day rollout."""
    fixed_path, flexible_path = generate_balances(tmp_path)
    rows = load_daily_cashflows(fixed_path)
    assert len(rows) == len(load_daily_cashflows(flexible_path)) == 180
    train(fixed_path, tmp_path)
    forecaster = FixedIncomeForecaster(tmp_path / "lgbm_forecaster.pkl")
    first_test = 7 + int((len(rows) - 7) * 0.8)
    observed = [
        BalancePoint(row.day, Decimal(str(row.balance))) for row in rows[:first_test]
    ]
    result = forecaster.forecast(observed)
    actual = np.asarray([row.balance for row in rows[first_test : first_test + 30]])
    predicted = np.asarray([float(point.balance) for point in result.balances])
    assert float(np.mean(np.abs(actual - predicted))) < 300_000
    assert float(np.mean(np.abs((actual - predicted) / actual))) < 0.1


def test_current_balance_changes_only_origin(fixed: FixedIncomeForecaster) -> None:
    """Changing the opening balance must not invent a historical delta."""
    first = fixed.forecast_30_days(10_000_000, date(2026, 3, 31))
    second = fixed.forecast_30_days(11_000_000, date(2026, 3, 31))
    for left, right in zip(first["trajectory"], second["trajectory"], strict=True):
        assert right["balance"] - left["balance"] == pytest.approx(1_000_000)


def test_selected_payday_drives_flags(fixed: FixedIncomeForecaster) -> None:
    """A user-selected next payday changes both calendar features and countdown."""
    vectors: list[np.ndarray] = []

    def predict(features: np.ndarray, *, num_threads: int) -> np.ndarray:
        """Capture the calendar feature while keeping balances unchanged."""
        vectors.append(features.copy())
        return np.zeros(1)

    fixed.model.booster_.predict = Mock(side_effect=predict)
    result = fixed.forecast(history(date(2026, 3, 31)), payday_date=date(2026, 4, 8))
    assert result.countdown_to_payday == 8
    assert vectors[4][0, 0] == 0
    assert vectors[7][0, 0] == 1
    with pytest.raises(ValueError, match="after the last"):
        fixed.forecast(history(date(2026, 3, 31)), payday_date=date(2026, 3, 31))
