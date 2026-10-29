"""Analytical EWMA burn rate, runway, and flexible-income depletion alerts."""

from collections.abc import Sequence
from datetime import date, timedelta
from decimal import Decimal
from math import fsum
from pathlib import Path
from typing import TypedDict

from app.domain.interfaces.forecaster_interface import (
    BalancePoint,
    CashflowForecast,
    ICashflowForecaster,
)
from app.infrastructure.ai.forecaster.features import (
    FLEXIBLE_DATA_PATH,
    finite_amount,
    load_daily_cashflows,
    validate_history,
)


class FlexibleIncomeResult(TypedDict):
    """JSON-safe runway; None represents unbounded runway at zero burn."""

    runway_days: float | None
    safe_to_spend: float
    trajectory_30d: list[float]
    alert_flag: bool
    alert_type: str | None
    burn_rate_daily: float


def ewma_burn_rate(expenses: Sequence[float], alpha: float = 0.3) -> float:
    """Apply EWMA oldest to newest, initialized with the first daily expense."""
    alpha = finite_amount(alpha, "alpha")
    if not 0 < alpha <= 1:
        raise ValueError("alpha must be in (0, 1]")
    burn = 0.0
    for index, value in enumerate(expenses):
        expense = finite_amount(value, "expense")
        if expense < 0:
            raise ValueError("Expenses must be nonnegative")
        burn = expense if index == 0 else alpha * expense + (1 - alpha) * burn
    return finite_amount(burn, "burn_rate_daily")


def _calculate(
    current_balance: float, expenses: Sequence[float], alpha: float, horizon_days: int
) -> FlexibleIncomeResult:
    """Calculate depletion and compare recent three-day spending with prior days."""
    balance = finite_amount(current_balance, "current_balance")
    expenses = [finite_amount(value, "expense") for value in expenses]
    burn = ewma_burn_rate(expenses, alpha)
    runway = max(balance, 0.0) / burn if burn > 0 else (0.0 if balance <= 0 else None)
    if runway is not None:
        runway = finite_amount(runway, "runway_days")
    spike = False
    if len(expenses) >= 4:
        baseline = fsum(expenses[:-3]) / len(expenses[:-3])
        recent_average = fsum(expenses[-3:]) / 3
        spike = recent_average > 1.3 * baseline
    alert = (runway is not None and runway <= 7) or spike
    return FlexibleIncomeResult(
        runway_days=runway,
        safe_to_spend=balance / 30,
        trajectory_30d=[
            finite_amount(balance - burn * day, "forecast balance")
            for day in range(1, horizon_days + 1)
        ],
        alert_flag=alert,
        alert_type="WINDFALL_DEPLETION" if alert else None,
        burn_rate_daily=burn,
    )


def calculate_runway(
    current_balance: float, expenses: list[float]
) -> FlexibleIncomeResult:
    """Return 30-day EWMA depletion, safe spending, runway, and alerts (alpha=0.3)."""
    return _calculate(current_balance, expenses, 0.3, 30)


class FlexibleIncomeForecaster(ICashflowForecaster):
    """Implement the domain port using observed expenses rather than balance deltas."""

    def __init__(
        self, alpha: float = 0.3, *, data_path: Path = FLEXIBLE_DATA_PATH
    ) -> None:
        """Configure deterministic EWMA; load the local CSV only when requested."""
        self.alpha = finite_amount(alpha, "alpha")
        if not 0 < self.alpha <= 1:
            raise ValueError("alpha must be in (0, 1]")
        self.data_path = Path(data_path)

    def load_expenses(self, as_of: date | None = None) -> list[float]:
        """Read daily expenses in date order, excluding observations after as_of."""
        rows = load_daily_cashflows(self.data_path)
        if as_of is not None:
            rows = [row for row in rows if row.day <= as_of]
            if not rows or rows[-1].day != as_of:
                raise ValueError(
                    "Expense history must contain the forecast's as-of date"
                )
        return [row.expense for row in rows]

    def calculate_runway(
        self, current_balance: float, expenses: list[float]
    ) -> FlexibleIncomeResult:
        """Calculate the requested 30-day metrics using this adapter's EWMA alpha."""
        return _calculate(current_balance, expenses, self.alpha, 30)

    def forecast(
        self, history: Sequence[BalancePoint], horizon_days: int = 30
    ) -> CashflowForecast:
        """Forecast from recorded expense burn; deposits never mask gross spending."""
        validate_history(history)
        if type(horizon_days) is not int or not 1 <= horizon_days <= 365:
            raise ValueError("horizon_days must be an integer in [1, 365]")
        as_of = history[-1].day
        expenses = self.load_expenses(as_of)
        result = _calculate(
            float(history[-1].balance), expenses, self.alpha, horizon_days
        )
        return CashflowForecast(
            balances=tuple(
                BalancePoint(as_of + timedelta(days=index), Decimal(str(balance)))
                for index, balance in enumerate(result["trajectory_30d"], 1)
            ),
            runway_days=result["runway_days"],
            alert_flag=result["alert_flag"],
            alert_type=result["alert_type"],
            safe_to_spend=Decimal(str(result["safe_to_spend"])),
        )
