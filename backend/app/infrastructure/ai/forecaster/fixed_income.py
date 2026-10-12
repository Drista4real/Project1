"""CPU LightGBM autoregressive forecasting for fixed-income users."""

import pickle
from collections.abc import Sequence
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path
from typing import TypedDict

import numpy as np
from lightgbm import LGBMRegressor
from lightgbm.basic import LightGBMError
from sklearn.utils.validation import check_is_fitted

from app.domain.interfaces.forecaster_interface import (
    BalancePoint,
    CashflowForecast,
    ICashflowForecaster,
)
from app.infrastructure.ai.forecaster.features import (
    FEATURE_NAMES,
    FIXED_DATA_PATH,
    MODEL_PATH,
    feature_vector,
    finite_amount,
    load_daily_cashflows,
    next_payday,
    validate_history,
)


class TrajectoryPoint(TypedDict):
    """JSON-safe forecast for one day."""

    date: str
    balance: float


class FixedIncomeResult(TypedDict):
    """Fixed-income forecast and pre-payday liquidity alert."""

    trajectory: list[TrajectoryPoint]
    countdown_to_payday: int
    alert_flag: bool
    alert_type: str | None


class FixedIncomeForecaster(ICashflowForecaster):
    """Reuse a single-thread CPU model with causal lags and calendar features."""

    def __init__(
        self,
        model_path: Path = MODEL_PATH,
        *,
        data_path: Path = FIXED_DATA_PATH,
        history: Sequence[BalancePoint] | None = None,
    ) -> None:
        """Load a trusted fitted checkpoint; defer CSV history reads until needed."""
        self.model_path = Path(model_path)
        self.data_path = Path(data_path)
        self.history = tuple(history) if history is not None else None
        try:
            with self.model_path.open("rb") as stream:
                model = pickle.load(stream)
        except FileNotFoundError as exc:
            raise FileNotFoundError(
                f"Missing forecaster checkpoint: {self.model_path}. "
                "Run train_forecaster.py."
            ) from exc
        except (
            OSError,
            pickle.UnpicklingError,
            EOFError,
            ImportError,
            AttributeError,
            ValueError,
        ) as exc:
            raise RuntimeError(
                f"Cannot load forecaster checkpoint: {self.model_path}"
            ) from exc
        if not isinstance(model, LGBMRegressor):
            raise ValueError("Forecaster checkpoint must contain an LGBMRegressor")
        check_is_fitted(model)
        if (
            model.n_features_in_ != len(FEATURE_NAMES)
            or tuple(model.feature_name_) != FEATURE_NAMES
            or getattr(model, "forecaster_target_", None) != "delta_balance"
        ):
            raise ValueError(
                "Checkpoint is not compatible with the delta pipeline; retrain Model 2"
            )
        self.model: LGBMRegressor = model
        self.model.set_params(n_jobs=1)

    def forecast(
        self,
        history: Sequence[BalancePoint],
        horizon_days: int = 30,
        *,
        payday_date: date | None = None,
    ) -> CashflowForecast:
        """Predict days after the final observation, updating both lags recursively."""
        validate_history(history, minimum=8)
        if type(horizon_days) is not int or not 1 <= horizon_days <= 365:
            raise ValueError("horizon_days must be an integer in [1, 365]")
        as_of = history[-1].day
        payday = payday_date or next_payday(as_of)
        if not isinstance(payday, date) or payday <= as_of:
            raise ValueError("payday_date must be after the last observed day")
        balances = [finite_amount(point.balance, "balance") for point in history[-8:]]
        deltas = list(np.diff(balances))
        balance = balances[-1]
        points: list[BalancePoint] = []
        alert = balances[-1] < 500_000
        for offset in range(1, horizon_days + 1):
            day = as_of + timedelta(days=offset)
            vector = feature_vector(day, deltas[-1], deltas[-7])
            if payday_date is not None:
                vector[0] = int(day.day == payday_date.day)
            try:
                prediction = self.model.booster_.predict(
                    vector.reshape(1, -1), num_threads=1
                )
            except (ValueError, RuntimeError, LightGBMError) as exc:
                raise RuntimeError(f"Cashflow prediction failed for {day}") from exc
            values = np.asarray(prediction)
            if values.shape != (1,):
                raise RuntimeError("Forecaster returned an invalid prediction shape")
            predicted_delta = finite_amount(float(values[0]), "predicted delta")
            deltas.append(predicted_delta)
            balance = finite_amount(balance + predicted_delta, "predicted balance")
            points.append(BalancePoint(day, Decimal(str(balance))))
            if day < payday and balance < 500_000:
                alert = True
        return CashflowForecast(
            balances=tuple(points),
            alert_flag=alert,
            alert_type="CASHFLOW_MISMATCH" if alert else None,
            countdown_to_payday=(payday - as_of).days,
        )

    def forecast_30_days(
        self,
        current_balance: float,
        start_date: date,
        *,
        payday_date: date | None = None,
    ) -> FixedIncomeResult:
        """Forecast the next 30 days using observed history through start_date.

        The supplied balance shifts the series without changing observed deltas.
        Eight consecutive
        observations ending on start_date are required; earlier lags are never invented.
        """
        current = finite_amount(current_balance, "current_balance")
        if not isinstance(start_date, date):
            raise ValueError("start_date must be a date")
        if self.history is not None:
            history = [point for point in self.history if point.day <= start_date]
        else:
            history = [
                BalancePoint(row.day, Decimal(str(row.balance)))
                for row in load_daily_cashflows(self.data_path)
                if row.day <= start_date
            ]
        validate_history(history, minimum=8)
        if history[-1].day != start_date:
            raise ValueError(
                "Balance history must end on start_date to initialize daily lags"
            )
        adjustment = Decimal(str(current)) - history[-1].balance
        history = [
            BalancePoint(point.day, point.balance + adjustment) for point in history
        ]
        result = self.forecast(history, payday_date=payday_date)
        return FixedIncomeResult(
            trajectory=[
                TrajectoryPoint(date=p.day.isoformat(), balance=float(p.balance))
                for p in result.balances
            ],
            countdown_to_payday=result.countdown_to_payday or 0,
            alert_flag=result.alert_flag,
            alert_type=result.alert_type,
        )
