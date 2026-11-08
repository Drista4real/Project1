# Deterministic budget engine

Date: 2026-11-01. Status: accepted.
Ticket: Ticket A of `docs/DYNAMIC_BUDGET_SPEC.md`.

The budget engine computes money. A language model never does. Plan creation,
the spendable budget, the daily allowance, the survival floor, the group split,
the purchase impact level and the rebalance proposal are all derived in Python
with fixed decimal arithmetic from validated inputs, so the same inputs always
produce the same result.

A **budget plan** is a projection. `public.budgets` stays the only source of
truth about envelope limits, and the plan reads those limits instead of copying
them. The engine therefore has one place where a limit lives.

The **survival floor** is derived from the fixed expenses per day rather than a
fixed constant, so a plan does not warn about a floor the user never chose. The
user can override it; the value is stored on the plan and carries a
`config_version`, so changing the derivation later does not rewrite old plans.

Rebalancing reduces cuttable pillars in a fixed order (`wants`, `culture`,
`unexpected`) and only then `needs`. A pillar whose categories carry limits is
funded: it may not be reduced below those limits and may never be zeroed. When
a purchase cannot be absorbed without breaking an envelope limit, the proposal
is infeasible and nothing is written.

The allocation, the confirmed purchase, the day's actual spend, the new plan
version and the audit event are applied by one database function,
`rebalance_plan`, in a single transaction. A version conflict is rejected and a
repeated idempotency key returns the stored result, so a partial allocation
cannot be left behind. This closes the gap recorded in ADR 0005, where
rebalancing still used several API writes.

The version conflict is raised with the PostgREST error code `PT409`, not with
the SQLSTATE `40001`. `40001` means `serialization_failure`, which PostgREST
treats as transient: it retries the transaction until the request times out, so
the client sees a 504 and the API reports 503 instead of a version conflict.
`PT409` is PostgREST's own `PT<status_code>` form and carries the HTTP status
directly. The API maps both `PT409` and the legacy `40001` to a 409 response,
so a database that was not migrated yet still reports the conflict correctly.

Plan creation carries an idempotency key as well. The key is stored on
`budget_plans` under a unique constraint on `(user_id, idempotency_key)`; a
repeated key returns the plan that already exists instead of inserting a
second plan and a second set of daily allocations. The key is optional in the
API and is derived on the server when a caller does not supply one, so a chat
model is never asked to produce a UUID.

The database function names the values it repeats. The SQL states it raises,
the allocation key and the rebalance status are declared once and used by
name, so a meaning cannot drift between two occurrences of a literal. A
repeated literal is a smell here for the same reason it is one in Python: it
is a place where the two occurrences can disagree.

The engine validates the envelope capacity inside the database through
`validate_envelope_capacity`, reusing the ADR 0005 rule instead of restating
it. Checking it in the database is what makes the check hold between two
concurrent clients.

A purchase impact verdict is one of `SAFE`, `WARNING_REBALANCE_NEEDED`,
`CRITICAL_DANGER` or `INSUFFICIENT_DATA`. When the balance history is shorter
than the forecaster needs, the result is `INSUFFICIENT_DATA`; the engine never
estimates a number it cannot support.

The remaining budget of a plan is read from real data. The plan's grant is the
spendable budget, and the money already used is the confirmed spending the
user recorded inside the plan window. Reading those rows is not a forecast:
the eight-point rule of Model 2 guards extrapolation of a balance series, and
this adapter extrapolates nothing. A plan without allocation rows has no
known balance, so the verdict is `INSUFFICIENT_DATA` rather than a guess.

The plan screen renders the engine's figures. It shows the daily allowance,
the survival floor, the spendable budget, the split across the four pillars,
the split across the planning groups and the day-by-day projection. The screen
computes nothing itself, and it reads the envelope limits from the plan rather
than copying them: `public.budgets` stays the only source of truth.

Apply `backend/supabase/migrations/202611010001_budget_plan_engine.sql` after
the previous migrations and before deploying the API. The migration adds
`budget_plans`, `daily_allocations` and `budget_plan_events` with row level
security scoped to the owner, and adds the two functions above. No live
database migration is performed as part of this workspace change.

Validation on 2026-11-01: the Python suite (675 tests, including 23 new
budget engine tests) passed with Ruff clean. Flutter analyze passed and the
ledger widget tests passed. The envelope screen tests fail on this branch
before and after this change with an unrelated `ListTile`/`DecoratedBox`
assertion.

The migration was applied to PostgreSQL 17 with the base schema, and the RPC
was exercised against real rows: the rebalance moved the allocation, bumped
the plan version, wrote exactly one purchase, returned the stored result for a
repeated idempotency key without writing twice, and rejected a stale
`expected_version`.

Validation on 2026-11-06 (Ticket A closed): the Python suite passed with 791
tests and Ruff clean. The Java end-to-end suite ran against a real PostgreSQL
17 with the Supabase migrations applied and passed 68 of 68 tests, of which
`BudgetPlanIT` covers 11 scenarios: plan creation, a stale version returning
409, an accepted rebalance bumping the version, an idempotency key replaying
the stored result, a missing key being rejected with 422, a purchase without
an account being rejected with 422, and cross-user reads being blocked by row
level security. The SonarCloud quality gate for the pull request passed with
a security rating of 1 and a duplicated line density of 0.28%.

The benchmark reads a recording the operator selects on the command line. The
path is untrusted input: the file is located by walking the real directory
entries of the path, so a name that only traverses somewhere else never
reaches the read, and the recording must be a regular file with a known audio
extension and a size a benchmark could use.
