# Model 2: adaptive cashflow

All numerical calculations use CPU LightGBM, EWMA, and Python arithmetic.
Both adapters inherit the pure-domain `ICashflowForecaster` protocol. The existing
`forecast(history, horizon_days=30)` method returns `CashflowForecast`, including
alert fields, so application use cases continue to use only domain interfaces.
`forecast_30_days` and `calculate_runway` also expose the requested dictionary APIs.

Install dependencies and train from the repository root:

```powershell
python -m pip install -r backend/requirements-forecaster.txt
python backend/scripts/generate_synthetic_data.py --balances-only
python backend/scripts/train_forecaster.py
```

Training requires `data/processed/balance_fixed.csv`, with exactly
`date,income,expense,balance` columns. Dates use ISO format and must be unique,
consecutive daily observations. Rows are sorted chronologically. Income and
expense must be finite nonnegative VND amounts; negative balances are valid.
The first seven days initialize lags and are omitted from training features.
The remaining observations split chronologically into 80% train and 20% test.
The generator defaults to 180 days for both fixed and flexible profiles. The
target is `delta_balance = diff(balance)` with the first delta initialized to 0.
The six ordered features are `is_payday` (day 5), `is_rent_day` (day 30),
`is_weekend`, `day_of_month`, `delta_lag_1`, and `delta_lag_7`. Observed current-day
income and expenses are excluded because they are unavailable for future dates.
LightGBM uses 100 estimators, learning rate 0.05, min_child_samples=2,
num_leaves=15, and random_state=42 to retain rare calendar shocks.

Training prints MAE, RMSE, and MAPE for both one-day-ahead evaluation and a fully
autoregressive holdout, including the first 30 test days when available.
One-day evaluation adds predicted delta to the previous observed balance;
the rollout accumulates predicted deltas and updates lags only from its own
predictions. Metrics compare reconstructed balances to actual balances.
Zero-balance targets
are excluded from MAPE and reported explicitly; all-zero targets have undefined
MAPE. The targets MAE <300,000 VND and MAPE <10% are reported as passed or unmet,
not assumed. Checkpoints come only from the training partition and are saved as
`weights/checkpoints/lgbm_forecaster.pkl` with feature names and a delta-target
marker embedded. Inference rejects old raw-balance checkpoints; retrain them.
Load only checkpoints from trusted training runs.

From `backend/`, forecast fixed-income balances:

```python
from datetime import date
from app.infrastructure.ai.forecaster.fixed_income import FixedIncomeForecaster

forecaster = FixedIncomeForecaster()
result = forecaster.forecast_30_days(5_000_000, date(2026, 3, 31))
```

`start_date` is the as-of date of `current_balance`. Forecast day one is the next
calendar day. Eight consecutive observed balance points ending on `start_date`
are required. The convenience method reads them from `balance_fixed.csv`, or
uses `history=` supplied to the constructor. The supplied current balance shifts
all historical balances equally, preserving observed deltas. The domain `forecast(history)` method needs
no CSV. Eight balances supply seven observed daily deltas. Lag 7 initially uses
observed deltas, then predicted deltas as the horizon advances. At each step,
the new balance is previous balance plus predicted delta. No artificial
historical balances are inserted.

By default, the next payday is the next strictly future day 5; on the fifth it
is next month's payday. An optional `payday_date=` on either forecast method
overrides the next payday and monthly payday covariate for demo scenarios.
The alert includes an already low current balance and any
predicted balance strictly below 500,000 VND before that payday. A low balance
on payday or afterward does not trigger this pre-payday alert. Output includes
`trajectory` (ISO dates and balances), `countdown_to_payday`, `alert_flag`, and
`alert_type` (`CASHFLOW_MISMATCH` or `None`).

For flexible income, expenses must be ordered oldest to newest:

```python
from app.infrastructure.ai.forecaster.flexible_income import FlexibleIncomeForecaster

forecaster = FlexibleIncomeForecaster()
expenses = forecaster.load_expenses()  # Reads balance_flexible.csv.
result = forecaster.calculate_runway(5_000_000, expenses)
```

The CSV has the same validated daily schema. `load_expenses(as_of)` excludes
future expenses and requires an observation on the as-of day. The domain
`forecast(history)` uses expenses from that CSV through the final balance date;
income deposits are never misinterpreted as reductions in gross spending.
Explicit `calculate_runway(current_balance, expenses)` calls need no file.

EWMA defaults to alpha=0.3 and initializes with the first expense; empty expenses
mean zero burn. Safe spending is current balance /30. The 30 projected balances
are current balance minus EWMA burn times day number (1..30), including negative
balances after exhaustion. Positive balance and zero burn produce
`runway_days=None`, a JSON-safe representation of unbounded runway. Nonpositive
balance gives zero runway. `WINDFALL_DEPLETION` alerts at runway <=7 or when
the last three expenses' mean exceeds 1.3 times the mean of the earlier expenses.
At least one earlier day is needed for that comparison; zero prior spending
followed by positive recent spending also alerts. Equality at 30% does not alert.
This flag tests spending conditions; the inputs do not establish a recent windfall.

Run focused tests from the repository root:

```powershell
python -m pytest -c backend/pyproject.toml --confcutdir=backend/tests/forecaster backend/tests/forecaster -q
```
