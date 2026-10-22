from decimal import Decimal

from supabase import Client


def included_account_total(client: Client, user_id: str) -> str:
    """Use wallets as the source of truth, including archived but included wallets."""
    total = Decimal(0)
    offset = 0
    while True:
        rows = (
            client.table("accounts")
            .select("balance")
            .eq("user_id", user_id)
            .eq("is_included_in_total", True)
            .order("id")
            .range(offset, offset + 499)
            .execute()
            .data
        )
        total += sum((Decimal(str(row["balance"])) for row in rows), Decimal(0))
        if len(rows) < 500:
            return str(total)
        offset += 500
