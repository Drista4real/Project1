# Envelope capacity and wallet totals

Date: 2026-10-22. Status: accepted.
Ticket: [#69](https://github.com/Drista4real/Project1/issues/69).

Category envelope forms reject a proposed limit when the sum of category limits
exceeds the configured pillar envelope or monthly budget. Equality is allowed.
An existing category's limit is replaced rather than counted twice; system
categories retain their actual pillar. Once pillar allocations are configured,
a missing pillar has zero capacity. Without a configured parent there is no
implicit cap derived from the category limits themselves.

Rebalancing rejects proposed allocations below existing category limits,
including changing a funded pillar to zero. Validation runs before writes,
reloads current data when saving, and preserves the form on rejection. The
warning identifies the parent, total, capacity and excess. This is a blocking
validation, as requested by the user, rather than an override confirmation.

These checks apply to the category envelope and rebalance forms. They do not
provide a database constraint against concurrent clients or writes through the
generic management API. Rebalancing still uses multiple existing API writes;
a network failure can leave a partial allocation and requires reload/retry.

Current assets are the sum of owned wallet balances with
`is_included_in_total = true`, regardless of wallet type. Archiving controls
wallet selection; inclusion controls the asset total. Opening balances are
assets and do not create monthly transaction income. Transfers do not create
income or spending.

Both `/overview` and `/manage/profile/me` read current assets from wallets with
decimal arithmetic and pagination. The stored profile balance is a cache; a
stale cache cannot override those API responses. Errors reading wallets must
surface rather than silently display zero or an old total.

The base schema includes the account-to-profile synchronization trigger so
wallet creation, balance edits, inclusion changes and deletion update the cache
without needing a transaction. Existing installations must apply
`backend/supabase/migrations/202610030002_management_guards.sql` (after the
preceding migration), which also backfills stale profile totals. Do not rerun
the base schema on an existing database. No live database migration is performed
as part of this workspace change.

Validation on 2026-10-22: Flutter suite (143 tests), an additional fresh-data
regression (all six focused allocation tests), Flutter analyze and the web build
passed. Docker Desktop ran the isolated Supabase/PostgreSQL stack with all
migrations: 51 Java integration/E2E tests and 126 Python tests passed, with Ruff
passing inside Docker. Wallet tests also read the stored profile balance directly
through PostgREST to verify the synchronization trigger independently of API
aggregation. Reports are retained under
`tests/backend-e2e/artifacts/finance-audit/` (ignored build artifacts).

Local Docker runs require explicit `E2E_LOCAL=true` and keep the existing fixed
internal service URL checks. Shell scripts use LF via `.gitattributes` so the
migration mount runs on Docker Desktop with a Windows checkout.
