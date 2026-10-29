"""Select a domain forecaster according to the user's income profile."""

from collections.abc import Sequence
from typing import Literal

from app.domain.interfaces.forecaster_interface import (
    BalancePoint,
    CashflowForecast,
    ICashflowForecaster,
)

IncomeType = Literal["fixed", "flexible"]


class ForecastCashflow:
    def __init__(
        self, fixed: ICashflowForecaster, flexible: ICashflowForecaster
    ) -> None:
        self.fixed = fixed
        self.flexible = flexible

    def execute(
        self,
        history: Sequence[BalancePoint],
        income_type: IncomeType,
        horizon_days: int = 30,
    ) -> CashflowForecast:
        if not history or horizon_days < 1:
            raise ValueError("Provide balance history and a positive forecast horizon")
        if income_type not in ("fixed", "flexible"):
            raise ValueError("Unsupported income type")
        forecaster = self.fixed if income_type == "fixed" else self.flexible
        return forecaster.forecast(history, horizon_days)
