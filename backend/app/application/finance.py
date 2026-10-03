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
