"""Domain contract and value objects for cashflow forecasting."""

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Protocol


@dataclass(frozen=True)
class BalancePoint:
    day: date
    balance: Decimal


@dataclass(frozen=True)
class CashflowForecast:
    balances: tuple[BalancePoint, ...]
    runway_days: float | None = None
    alert_flag: bool = False
    alert_type: str | None = None
    countdown_to_payday: int | None = None
    safe_to_spend: Decimal | None = None


class ICashflowForecaster(Protocol):
    def forecast(
        self, history: Sequence[BalancePoint], horizon_days: int = 30
    ) -> CashflowForecast:
        """Forecast future balances and optional days until cash is exhausted."""
        ...
