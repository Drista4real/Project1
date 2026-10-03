from datetime import UTC, datetime
from decimal import Decimal

from supabase import Client


class SupabaseFinanceQueries:
    def __init__(self, client: Client, user_id: str):
        self.client = client
        self.user_id = user_id

    def categories(self):
        return (
            self.client.table("categories")
            .select("id, name, icon, color, is_income, pillar")
            .or_(f"user_id.is.null,user_id.eq.{self.user_id}")
            .order("id")
            .execute()
            .data
        )

    def accounts(self):
        return (
            self.client.table("accounts")
            .select("id, name, balance, currency")
            .eq("user_id", self.user_id)
            .eq("is_archived", False)
            .order("id")
            .execute()
            .data
        )

    def overview(self):
        now = datetime.now(UTC)
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        end = (
            start.replace(year=start.year + 1, month=1)
            if start.month == 12
            else (start.replace(month=start.month + 1))
        )
        profile = (
            self.client.table("profiles")
            .select("current_balance")
            .eq("id", self.user_id)
            .execute()
            .data
        )
        income = Decimal(0)
        expense = Decimal(0)
        offset = 0
        while True:
            rows = (
                self.client.table("transactions")
                .select("amount, transaction_type")
                .eq("user_id", self.user_id)
                .gte("transaction_date", start.isoformat())
                .lt("transaction_date", end.isoformat())
                .order("id")
                .range(offset, offset + 499)
                .execute()
                .data
            )
            for row in rows:
                if row["transaction_type"] == "income":
                    income += Decimal(str(row["amount"]))
                elif row["transaction_type"] == "expense":
                    expense += Decimal(str(row["amount"]))
            if len(rows) < 500:
                break
            offset += 500
        return {
            "current_balance": str(profile[0]["current_balance"] if profile else 0),
            "monthly_income": str(income),
            "monthly_expense": str(expense),
        }
