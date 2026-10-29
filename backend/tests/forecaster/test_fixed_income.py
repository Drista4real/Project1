"""Unit tests for fixed income forecaster."""

from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

import numpy as np
import pandas as pd
import pytest
from lightgbm import LGBMRegressor
from sklearn.utils.validation import NotFittedError

from app.domain.interfaces.forecaster_interface import BalancePoint, CashflowForecast
from app.infrastructure.ai.forecaster.features import (
    FEATURE_NAMES,
)
from app.infrastructure.ai.forecaster.fixed_income import (
    FixedIncomeForecaster,
)


def _create_fitted_model() -> LGBMRegressor:
    """Create a fitted LGBMRegressor with correct feature names that can be pickled."""
    model = LGBMRegressor(n_estimators=1, random_state=42, verbose=-1, n_jobs=1)
    n_features = len(FEATURE_NAMES)
    rng = np.random.default_rng(42)
    X_train = rng.random((20, n_features), dtype=np.float32)
    y_train = rng.random(20, dtype=np.float32)
    # Train with DataFrame to set correct feature names
    df = pd.DataFrame(X_train, columns=FEATURE_NAMES)
    model.fit(df, y_train)
    model.forecaster_target_ = "delta_balance"
    return model


class TestFixedIncomeForecasterInit:
    """Tests for FixedIncomeForecaster initialization."""

    def _create_forecaster(self, model_path: Path):
        """Helper to create forecaster with explicit model_path."""
        return FixedIncomeForecaster(model_path=model_path)

    def test_init_loads_model(self, tmp_path: Path) -> None:
        """Test initialization loads model from checkpoint."""
        import pickle

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(_create_fitted_model()))

        forecaster = self._create_forecaster(model_path)
        assert forecaster.model is not None

    def test_init_missing_model_file(self, tmp_path: Path) -> None:
        """Test initialization fails when model file missing."""
        with pytest.raises(FileNotFoundError, match="Missing forecaster checkpoint"):
            self._create_forecaster(tmp_path / "missing.pkl")

    def test_init_invalid_model_type(self, tmp_path: Path) -> None:
        """Test initialization fails when model is not LGBMRegressor."""
        import pickle

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps("not a model"))

        with pytest.raises(
            ValueError, match="Forecaster checkpoint must contain an LGBMRegressor"
        ):
            self._create_forecaster(model_path)

    def test_init_unfitted_model(self, tmp_path: Path) -> None:
        """Test initialization fails when model is not fitted."""
        model = LGBMRegressor()
        import pickle

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(model))

        with pytest.raises(NotFittedError):
            self._create_forecaster(model_path)

    def test_init_wrong_feature_count(self, tmp_path: Path) -> None:
        """Test initialization fails when feature count mismatches."""
        import pickle

        model = LGBMRegressor(n_estimators=1, random_state=42, verbose=-1, n_jobs=1)
        X_train = (
            np.random.default_rng(42).random((20, 10)).astype(np.float32)
        )  # Wrong feature count
        y_train = np.random.default_rng(42).random((20,)).astype(np.float32)
        df = pd.DataFrame(X_train)
        model.fit(df, y_train)
        model.forecaster_target_ = "delta_balance"

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(model))

        with pytest.raises(ValueError, match="not compatible with the delta pipeline"):
            self._create_forecaster(model_path)

    def test_init_wrong_feature_names(self, tmp_path: Path) -> None:
        """Test initialization fails when feature names mismatch."""
        import pickle

        # Create a real model with wrong feature names by training with DataFrame with
        # wrong columns
        model = LGBMRegressor(n_estimators=1, random_state=42, verbose=-1, n_jobs=1)
        X_train = (
            np.random.default_rng(42)
            .random((20, len(FEATURE_NAMES)))
            .astype(np.float32)
        )
        y_train = np.random.default_rng(42).random((20,)).astype(np.float32)
        # Train with wrong column names (unique)
        wrong_names = ["wrong1", "wrong2", "wrong3", "wrong4", "wrong5", "wrong6"]
        df = pd.DataFrame(X_train, columns=wrong_names)
        model.fit(df, y_train)
        model.forecaster_target_ = "delta_balance"

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(model))

        with pytest.raises(ValueError, match="not compatible with the delta pipeline"):
            self._create_forecaster(model_path)

    def test_init_wrong_target(self, tmp_path: Path) -> None:
        """Test initialization fails when target mismatches."""
        import pickle

        model = _create_fitted_model()
        model.forecaster_target_ = "wrong_target"

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(model))

        with pytest.raises(ValueError, match="not compatible with the delta pipeline"):
            self._create_forecaster(model_path)

    def test_init_sets_n_jobs_to_one(self, tmp_path: Path) -> None:
        """Test initialization sets n_jobs=1."""
        import pickle

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(_create_fitted_model()))

        forecaster = self._create_forecaster(model_path)
        assert forecaster.model.n_jobs == 1


class TestFixedIncomeForecasterForecast:
    """Tests for FixedIncomeForecaster.forecast method."""

    @pytest.fixture
    def fitted_model(self) -> LGBMRegressor:
        """Create a fitted LGBMRegressor with proper attributes."""
        return _create_fitted_model()

    @pytest.fixture
    def forecaster(self, tmp_path: Path, fitted_model):
        """Create a forecaster with mocked model."""
        import pickle

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(fitted_model))

        return FixedIncomeForecaster(model_path=model_path)

    @pytest.fixture
    def valid_history(self):
        """Create valid history with 8+ consecutive days."""
        base_date = date(2024, 1, 1)
        return [
            BalancePoint(
                base_date + timedelta(days=i), Decimal(str(5000000 + i * 10000))
            )
            for i in range(10)
        ]

    def test_forecast_valid_input(self, forecaster, valid_history, fitted_model):
        """Test forecast with valid input."""
        # Mock the booster predict to return a reasonable delta
        with patch.object(
            forecaster.model.booster_, "predict", return_value=np.array([50000.0])
        ):
            result = forecaster.forecast(valid_history, horizon_days=30)

            assert isinstance(result, CashflowForecast)
            assert len(result.balances) == 30
            assert result.countdown_to_payday >= 0
            assert isinstance(result.alert_flag, bool)
            assert result.alert_type in (None, "CASHFLOW_MISMATCH")

    def test_forecast_insufficient_history(self, forecaster):
        """Test forecast fails with insufficient history."""
        history = [BalancePoint(date(2024, 1, 1), Decimal("5000000"))]
        with pytest.raises(
            ValueError, match="At least 8 consecutive daily balance points are required"
        ):
            forecaster.forecast(history)

    def test_forecast_non_consecutive_history(self, forecaster, valid_history):
        """Test forecast fails with non-consecutive history."""
        history = valid_history[:8] + [valid_history[9]]
        with pytest.raises(
            ValueError, match="History must contain consecutive daily dates"
        ):
            forecaster.forecast(history)

    def test_forecast_invalid_horizon_days_type(self, forecaster, valid_history):
        """Test forecast fails with non-int horizon_days."""
        with pytest.raises(ValueError, match="horizon_days must be an integer in"):
            forecaster.forecast(valid_history, horizon_days=30.0)  # type: ignore

    def test_forecast_horizon_days_too_small(self, forecaster, valid_history):
        """Test forecast fails with horizon_days < 1."""
        with pytest.raises(ValueError, match="horizon_days must be an integer in"):
            forecaster.forecast(valid_history, horizon_days=0)

    def test_forecast_horizon_days_too_large(self, forecaster, valid_history):
        """Test forecast fails with horizon_days > 365."""
        with pytest.raises(ValueError, match="horizon_days must be an integer in"):
            forecaster.forecast(valid_history, horizon_days=366)

    def test_forecast_invalid_payday_date(self, forecaster, valid_history):
        """Test forecast fails with invalid payday_date."""
        as_of = valid_history[-1].day
        with pytest.raises(ValueError, match="payday_date must be after"):
            forecaster.forecast(valid_history, payday_date=as_of)

    def test_forecast_custom_payday(self, forecaster, valid_history, fitted_model):
        """Test forecast with custom payday_date."""
        as_of = valid_history[-1].day
        custom_payday = as_of + timedelta(days=10)
        with patch.object(
            forecaster.model.booster_, "predict", return_value=np.array([50000.0])
        ):
            result = forecaster.forecast(
                valid_history, horizon_days=15, payday_date=custom_payday
            )

            assert result.countdown_to_payday == 10

    def test_forecast_uses_recursive_lags(
        self, forecaster, valid_history, fitted_model
    ):
        """Test that forecast updates lags recursively."""
        with patch.object(
            forecaster.model.booster_, "predict", return_value=np.array([50000.0])
        ) as predict:
            result = forecaster.forecast(valid_history, horizon_days=8)

        assert predict.call_count == 8
        vectors = [call.args[0][0] for call in predict.call_args_list]
        assert vectors[0][4] == 10000.0
        assert vectors[1][4] == 50000.0
        assert vectors[6][5] == 10000.0
        assert vectors[7][5] == 50000.0
        assert result.balances[-1].balance == valid_history[-1].balance + 400000

    def test_forecast_alert_flag_low_balance(
        self, forecaster, valid_history, fitted_model
    ):
        """Test alert_flag is True when balance drops below 500k."""
        # Make predictions that reduce balance below 500k
        with patch.object(
            forecaster.model.booster_, "predict", return_value=np.array([-1000000.0])
        ):
            # Set last balance low
            low_history = [
                BalancePoint(
                    date(2024, 1, 1) + timedelta(days=i),
                    Decimal(str(600000 - i * 50000)),
                )
                for i in range(10)
            ]

            result = forecaster.forecast(low_history, horizon_days=5)
            assert result.alert_flag is True
            assert result.alert_type == "CASHFLOW_MISMATCH"

    def test_forecast_model_prediction_failure(
        self, forecaster, valid_history, fitted_model
    ):
        """Test forecast fails when model prediction fails."""
        with patch.object(
            forecaster.model.booster_,
            "predict",
            side_effect=ValueError("Prediction failed"),
        ):
            with pytest.raises(RuntimeError, match="Cashflow prediction failed"):
                forecaster.forecast(valid_history, horizon_days=1)

    def test_forecast_invalid_prediction_shape(
        self, forecaster, valid_history, fitted_model
    ):
        """Test forecast fails when prediction shape is invalid."""
        with patch.object(
            forecaster.model.booster_, "predict", return_value=np.array([[1, 2]])
        ):  # Wrong shape
            with pytest.raises(
                RuntimeError, match="Forecaster returned an invalid prediction shape"
            ):
                forecaster.forecast(valid_history, horizon_days=1)

    def test_forecast_non_finite_prediction(
        self, forecaster, valid_history, fitted_model
    ):
        """Test forecast fails when prediction is non-finite."""
        with patch.object(
            forecaster.model.booster_, "predict", return_value=np.array([float("nan")])
        ):
            with pytest.raises(
                ValueError, match="predicted delta must be a finite number"
            ):
                forecaster.forecast(valid_history, horizon_days=1)


class TestFixedIncomeForecasterForecast30Days:
    """Tests for FixedIncomeForecaster.forecast_30_days method."""

    @pytest.fixture
    def fitted_model(self) -> LGBMRegressor:
        """Create a fitted LGBMRegressor with proper attributes."""
        return _create_fitted_model()

    @pytest.fixture
    def forecaster_with_history(self, tmp_path: Path, fitted_model):
        """Create a forecaster with embedded history."""
        import pickle

        model_path = tmp_path / "model.pkl"
        model_path.write_bytes(pickle.dumps(fitted_model))

        # Create test CSV data with history ending on 2024-01-15 (start_date for tests)
        csv_content = "date,income,expense,balance\n"
        base_date = date(2024, 1, 1)
        for i in range(15):  # 15 days, ending on 2024-01-15
            csv_content += (
                f"{base_date + timedelta(days=i)},1000,500,{5000000 + i * 10000}\n"
            )
        csv_path = tmp_path / "cashflow.csv"
        csv_path.write_text(csv_content)

        # Pass data_path explicitly since default parameter is evaluated at function
        # definition time
        forecaster = FixedIncomeForecaster(model_path=model_path, data_path=csv_path)
        return forecaster

    def test_forecast_30_days_valid(self, forecaster_with_history, fitted_model):
        """Test forecast_30_days with valid input."""
        with patch.object(
            forecaster_with_history.model.booster_,
            "predict",
            return_value=np.array([50000.0]),
        ):
            start_date = date(2024, 1, 15)  # This matches the last date in CSV
            result = forecaster_with_history.forecast_30_days(
                current_balance=5500000.0,
                start_date=start_date,
            )

            assert isinstance(result, dict)
            assert "trajectory" in result
            assert "countdown_to_payday" in result
            assert "alert_flag" in result
            assert "alert_type" in result
            assert len(result["trajectory"]) == 30
            assert result["trajectory"][0] == {
                "date": "2024-01-16",
                "balance": 5550000.0,
            }
            assert all(isinstance(p, dict) for p in result["trajectory"])
            assert all("date" in p and "balance" in p for p in result["trajectory"])

    def test_forecast_30_days_invalid_current_balance(self, forecaster_with_history):
        """Test forecast_30_days fails with invalid current_balance."""
        with pytest.raises(ValueError, match="current_balance must be a finite number"):
            forecaster_with_history.forecast_30_days(
                current_balance=float("nan"),
                start_date=date(2024, 1, 15),
            )

    def test_forecast_30_days_invalid_start_date(self, forecaster_with_history):
        """Test forecast_30_days fails with invalid start_date."""
        with pytest.raises(ValueError, match="start_date must be a date"):
            forecaster_with_history.forecast_30_days(
                current_balance=5500000.0,
                start_date="2024-01-15",  # type: ignore
            )

    def test_forecast_30_days_history_must_end_on_start_date(
        self, forecaster_with_history
    ):
        """Test forecast_30_days fails when history doesn't end on start_date."""
        with pytest.raises(ValueError, match="Balance history must end on start_date"):
            forecaster_with_history.forecast_30_days(
                current_balance=5500000.0,
                start_date=date(2024, 2, 1),  # After available data
            )

    def test_forecast_30_days_insufficient_history(self, forecaster_with_history):
        """Test forecast_30_days fails with insufficient history."""
        with pytest.raises(
            ValueError, match="At least 8 consecutive daily balance points are required"
        ):
            forecaster_with_history.forecast_30_days(
                current_balance=5500000.0,
                start_date=date(2024, 1, 5),  # Only 5 days of data
            )

    def test_forecast_30_days_custom_payday(
        self, forecaster_with_history, fitted_model
    ):
        """Test forecast_30_days with custom payday_date."""
        with patch.object(
            forecaster_with_history.model.booster_,
            "predict",
            return_value=np.array([50000.0]),
        ):
            start_date = date(2024, 1, 15)
            payday = date(2024, 2, 5)
            result = forecaster_with_history.forecast_30_days(
                current_balance=5500000.0,
                start_date=start_date,
                payday_date=payday,
            )

            assert result["countdown_to_payday"] == (payday - start_date).days
