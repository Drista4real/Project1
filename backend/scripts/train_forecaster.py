"""Train a chronological LightGBM model for fixed-income cashflow."""

# Imports follow the bootstrap so direct script execution works from any directory.
# ruff: noqa: E402
import argparse
import logging
import pickle
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "backend") not in sys.path:
    sys.path.insert(0, str(ROOT / "backend"))

import numpy as np
from lightgbm import LGBMRegressor
from lightgbm.basic import LightGBMError
from sklearn.metrics import mean_absolute_error, mean_squared_error

from app.infrastructure.ai.forecaster.features import (
    FEATURE_NAMES,
    FIXED_DATA_PATH,
    DailyCashflow,
    feature_vector,
    load_daily_cashflows,
)


def build_features(rows: list[DailyCashflow]) -> tuple[np.ndarray, np.ndarray]:
    """Build diff(balance), initializing delta[0]=0, and lag only past deltas."""
    if len(rows) < 10:
        raise ValueError(
            "Need at least 10 consecutive days for lag features and an 80/20 split"
        )
    balances = np.asarray([row.balance for row in rows], dtype=np.float64)
    deltas = np.diff(balances, prepend=balances[0])
    features = np.stack(
        [
            feature_vector(rows[i].day, deltas[i - 1], deltas[i - 7])
            for i in range(7, len(rows))
        ]
    )
    return features, deltas[7:]


def report_metrics(actual: np.ndarray, predicted: np.ndarray, label: str) -> None:
    """Print VND errors and percentage error; zero targets have undefined MAPE."""
    if not np.isfinite(predicted).all():
        raise RuntimeError("Forecaster returned non-finite test predictions")
    mae = float(mean_absolute_error(actual, predicted))
    rmse = float(np.sqrt(mean_squared_error(actual, predicted)))
    nonzero = actual != 0
    print(f"{label}: MAE={mae:.2f} VND, RMSE={rmse:.2f} VND")
    if nonzero.any():
        mape = float(
            np.mean(np.abs((actual[nonzero] - predicted[nonzero]) / actual[nonzero]))
            * 100
        )
        print(
            f"{label}: MAPE={mape:.2f}% "
            f"(zero-balance targets excluded: {int((~nonzero).sum())})"
        )
        status = "PASS" if mae < 300000 and mape < 10 else "NOT MET"
        print(f"{label}: targets MAE < 300000 and MAPE < 10%: {status}")
    else:
        print(f"{label}: MAPE=undefined (all test balances are zero)")


def train(data_path: Path, output_dir: Path) -> None:
    """Evaluate an 80/20 chronological split and save the fitted training model."""
    rows = load_daily_cashflows(data_path)
    features, targets = build_features(rows)
    split = int(len(targets) * 0.8)
    model = LGBMRegressor(
        n_estimators=100,
        learning_rate=0.05,
        min_child_samples=2,
        num_leaves=15,
        random_state=42,
        n_jobs=1,
        verbosity=-1,
    )
    model.fit(features[:split], targets[:split], feature_name=list(FEATURE_NAMES))
    model.forecaster_target_ = "delta_balance"
    predicted_deltas = np.asarray(
        model.booster_.predict(features[split:], num_threads=1)
    )
    first_test = 7 + split
    actual_balances = np.asarray([row.balance for row in rows[first_test:]])
    previous_balances = np.asarray([row.balance for row in rows[first_test - 1 : -1]])
    predictions = previous_balances + predicted_deltas
    print(
        f"Chronological split: {split} train / {len(targets) - split} test "
        "(7 warm-up days)"
    )
    report_metrics(actual_balances, predictions, "One-day-ahead")
    # Also report a genuine rollout: future observed balances never feed the lags.
    observed_balances = [row.balance for row in rows[:first_test]]
    observed_deltas = list(np.diff(observed_balances, prepend=observed_balances[0]))
    current_balance = observed_balances[-1]
    rollout: list[float] = []
    for row in rows[first_test:]:
        vector = feature_vector(row.day, observed_deltas[-1], observed_deltas[-7])
        predicted_delta = float(
            model.booster_.predict(vector.reshape(1, -1), num_threads=1)[0]
        )
        observed_deltas.append(predicted_delta)
        current_balance += predicted_delta
        rollout.append(current_balance)
    report_metrics(actual_balances, np.asarray(rollout), "Autoregressive holdout")
    horizon = min(30, len(rollout))
    report_metrics(
        actual_balances[:horizon],
        np.asarray(rollout[:horizon]),
        f"Autoregressive {horizon}-day",
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / "lgbm_forecaster.pkl"
    try:
        with path.open("wb") as stream:
            pickle.dump(model, stream, protocol=pickle.HIGHEST_PROTOCOL)
    except (OSError, pickle.PicklingError) as exc:
        raise RuntimeError(f"Cannot save forecaster checkpoint: {path}") from exc
    print(f"Saved forecaster: {path}")


def main() -> None:
    """Read CLI options and explain invalid data or missing dependencies."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=FIXED_DATA_PATH)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "weights/checkpoints")
    args = parser.parse_args()
    try:
        train(args.data, args.output_dir)
    except (OSError, ValueError, RuntimeError, LightGBMError) as exc:
        logging.error("Forecaster training failed: %s", exc)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
