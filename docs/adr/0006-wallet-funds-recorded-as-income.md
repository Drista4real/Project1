# Explicit income when adding wallet funds

Date: 2026-10-22. Status: accepted.
Ticket: [#70](https://github.com/Drista4real/Project1/issues/70).

The user clarified that the 10 million entered for their new e-wallet is newly
received income. Wallet creation exposes **Ghi nhận số tiền này là thu nhập mới**.
The existing-funds default remains available for users entering assets they
already owned. This extends ADR 0005 without inferring income from every balance
edit or changing historical financial records automatically.

With the income option enabled, the database creates a zero-balance wallet and
one income transaction for the entered positive amount, dated at the time of
recording. Existing transaction triggers update the wallet and profile total.
The complete operation is one PostgreSQL transaction. Failure rolls everything
back; a stable request identifier makes retries return the same wallet without
inserting another income. Reusing that identifier with different input fails.
The option and request identifier are create-only API fields, not account edits.

For a wallet already created with an opening balance, its detail sheet offers
**Ghi nhận số dư ban đầu là thu nhập**. Confirmation states that the income is
recorded today while the wallet balance remains the same. The database locks
the owned wallet, checks its expected balance and rejects archived wallets,
nonpositive amounts, wallets with any existing transaction, and repeat recording
under a different request identifier. Resetting the opening amount to zero and
inserting the income happen in one transaction, preserving assets exactly once.
Concurrent transaction writes synchronize through the existing account locks.

The RPC uses the caller's identity and RLS, never a service-role key. It ignores
no ownership boundary and serializes matching requests before creating records.
The receipt is stored on the owned account, including the original request
payload, so retries after a later expense cannot restore or inflate the balance.

Reports use the resulting ledger income, including income without a category.
Both budget and category-envelope views display income for the selected month
and the current included-wallet balance. The balance is explicitly labelled as
current, including when viewing a past budget month. Saved envelope limits remain
user decisions. Rebalance offers **Dùng số dư ví làm ngân sách**, which fills the
form and requires saving; a new budget form can suggest the current positive
wallet balance. Existing allocations are not silently overwritten.

Apply `backend/supabase/migrations/202610220001_wallet_initial_income.sql` after
the previous migrations before deploying the API/frontend. Missing RPC support
returns an actionable error and does not fall back to separate wallet and ledger
writes. No production migration or automatic reclassification of real records is
performed by these changes.

Validation on 2026-10-22: 149 Flutter tests passed, including refreshing reports
after an uncategorized wallet income, preserving saved budgets while filling the
allocation form, stable retry identifiers, confirmation and hiding the completed
opening-income action. Flutter analyze and the web build passed. The final
Docker run passed 56 Java integration/E2E tests and 131 Python tests with Ruff.
The wallet E2E cases independently check reclassification without changing
assets, idempotent retries after spending, cross-user rejection, stale balance
rejection, used-wallet rejection and rollback after a ledger overflow. Reports
are retained in `tests/backend-e2e/artifacts/wallet-income/`; the isolated stack
and test credentials were removed.
