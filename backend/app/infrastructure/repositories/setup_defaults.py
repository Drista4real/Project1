"""The reads that prefill the monthly setup, scoped to one owner."""

from datetime import date

from supabase import Client

from app.infrastructure.repositories.account_totals import included_account_total


class SupabaseSetupDefaultsSource:
    """Read wallets, recurring transactions, the profile and plan presence."""

    def __init__(self, client: Client, user_id: str) -> None:
        self.client = client
        self.user_id = user_id

    def available_balance(self) -> str:
        return included_account_total(self.client, self.user_id)

    def recurring_income(self, after: date) -> list[dict]:
        """Active recurring incomes due after ``after``, earliest first."""
        return (
            self._recurring("income")
            .gt("next_execution_date", after.isoformat())
            .order("next_execution_date")
            .limit(50)
            .execute()
            .data
            or []
        )

    def recurring_expenses(self, start: date, end: date) -> list[dict]:
        """Active recurring expenses due between ``start`` and ``end``."""
        return (
            self._recurring("expense")
            .gte("next_execution_date", start.isoformat())
            .lte("next_execution_date", end.isoformat())
            .order("next_execution_date")
            .limit(100)
            .execute()
            .data
            or []
        )

    def profile(self) -> dict:
        result = (
            self.client.table("profiles")
            .select("payroll_day,monthly_savings_target")
            .eq("id", self.user_id)
            .maybe_single()
            .execute()
        )
        return (result.data if result is not None else None) or {}

    def has_plans(self) -> bool:
        rows = (
            self.client.table("budget_plans")
            .select("id")
            .eq("user_id", self.user_id)
            .limit(1)
            .execute()
            .data
        )
        return bool(rows)

    def _recurring(self, kind: str):
        return (
            self.client.table("recurring_transactions")
            .select("description,amount,next_execution_date")
            .eq("user_id", self.user_id)
            .eq("transaction_type", kind)
            .eq("is_active", True)
        )
