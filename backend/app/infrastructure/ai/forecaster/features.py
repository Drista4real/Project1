"""Validated daily data and identical lag/calendar features for Model 2."""

import csv
import math
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal
from pathlib import Path

import numpy as np

from app.domain.interfaces.forecaster_interface import BalancePoint

ROOT = Path(__file__).resolve().parents[5]
FIXED_DATA_PATH = ROOT / "data/processed/balance_fixed.csv"
FLEXIBLE_DATA_PATH = ROOT / "data/processed/balance_flexible.csv"
MODEL_PATH = ROOT / "weights/checkpoints/lgbm_forecaster.pkl"
FEATURE_NAMES = (
    "is_payday",
    "is_rent_day",
    "is_weekend",
    "day_of_month",
    "delta_lag_1",
    "delta_lag_7",
)


@dataclass(frozen=True)
class DailyCashflow:
    """One observed day; income and expense are nonnegative VND amounts."""

    day: date
    income: float
    expense: float
    balance: float


def finite_amount(value: float | str | Decimal, name: str) -> float:
    """Reject nonnumeric, boolean, NaN, and infinite financial amounts."""
    if isinstance(value, bool):
        raise ValueError(f"{name} must be a finite number")
    try:
        amount = float(value)
    except (ValueError, TypeError, OverflowError) as exc:
        raise ValueError(f"{name} must be a finite number") from exc
    if not math.isfinite(amount):
        raise ValueError(f"{name} must be a finite number")
    return amount


def load_daily_cashflows(path: Path) -> list[DailyCashflow]:
    """Read UTF-8 daily observations, sort dates, and reject gaps or duplicates."""
    rows: list[DailyCashflow] = []
    try:
        with path.open(encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            if (
                reader.fieldnames is None
                or set(reader.fieldnames)
                != {
                    "date",
                    "income",
                    "expense",
                    "balance",
                }
                or len(reader.fieldnames) != 4
            ):
                raise ValueError("CSV requires date,income,expense,balance columns")
            for line, row in enumerate(reader, 2):
                try:
                    if None in row:
                        raise ValueError("Unexpected extra columns")
                    day = date.fromisoformat(row["date"])
                    income = finite_amount(row["income"], "income")
                    expense = finite_amount(row["expense"], "expense")
                    balance = finite_amount(row["balance"], "balance")
                    if income < 0 or expense < 0:
                        raise ValueError("Income and expense must be nonnegative")
                except (ValueError, TypeError, KeyError) as exc:
                    raise ValueError(
                        f"Invalid daily cashflow at row {line}: {exc}"
                    ) from exc
                rows.append(DailyCashflow(day, income, expense, balance))
    except FileNotFoundError as exc:
        raise FileNotFoundError(f"Missing daily cashflow CSV: {path}") from exc
    except (OSError, UnicodeError, csv.Error) as exc:
        raise RuntimeError(f"Cannot read daily cashflow CSV: {path}") from exc
    if not rows:
        raise ValueError("Daily cashflow CSV must not be empty")
    rows.sort(key=lambda row: row.day)
    for previous, current in zip(rows, rows[1:], strict=False):
        if current.day - previous.day != timedelta(days=1):
            raise ValueError(
                "Cashflow dates must be unique and consecutive daily dates"
            )
    return rows


def validate_history(history: Sequence[BalancePoint], minimum: int = 1) -> None:
    """Require finite, consecutive daily balances in chronological order."""
    if len(history) < minimum:
        raise ValueError(
            f"At least {minimum} consecutive daily balance points are required"
        )
    for point in history:
        finite_amount(point.balance, "balance")
        if not isinstance(point.day, date):
            raise ValueError("History dates must be date instances")
    for previous, current in zip(history, history[1:], strict=False):
        if current.day - previous.day != timedelta(days=1):
            raise ValueError("History must contain consecutive daily dates in order")


def feature_vector(day: date, lag_1: float, lag_7: float) -> np.ndarray:
    """Build known calendar covariates followed by causal delta lags."""
    return np.asarray(
        [
            int(day.day == 5),
            int(day.day == 30),
            int(day.weekday() >= 5),
            day.day,
            finite_amount(lag_1, "delta_lag_1"),
            finite_amount(lag_7, "delta_lag_7"),
        ],
        dtype=np.float64,
    )


def next_payday(as_of: date) -> date:
    """Return the next strictly future fifth, including month/year rollover."""
    if as_of.day < 5:
        return as_of.replace(day=5)
    next_month = as_of.replace(day=28) + timedelta(days=4)
    return next_month.replace(day=5)
