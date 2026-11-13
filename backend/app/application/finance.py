from decimal import Decimal

from app.domain.finance import FinanceQueries


class FinanceService:
    def __init__(self, queries: FinanceQueries):
        self.queries = queries

    def accounts(self):
        return self.queries.accounts()

    def categories(self):
        return self.queries.categories()

    def overview(self):
        return self.queries.overview()

    def set_balance(self, amount: Decimal) -> dict:
        """Make the available balance equal ``amount``.

        The app shows one balance: the sum of the wallets included in the
        total. The primary wallet (the oldest one not archived) absorbs the
        difference, so other included wallets keep their own balance. No
        ledger transaction is written; a balance edit is not income (ADR 0006).
        """
        wallets = self.queries.included_wallets()
        usable = [wallet for wallet in wallets if not wallet.get("is_archived")]
        if not usable:
            self.queries.create_wallet(amount)
            return {"current_balance": str(amount)}
        primary = min(usable, key=lambda wallet: wallet["id"])
        others = sum(
            (
                Decimal(str(wallet["balance"]))
                for wallet in wallets
                if wallet["id"] != primary["id"]
            ),
            Decimal(0),
        )
        self.queries.set_wallet_balance(primary["id"], amount - others)
        return {"current_balance": str(amount)}
