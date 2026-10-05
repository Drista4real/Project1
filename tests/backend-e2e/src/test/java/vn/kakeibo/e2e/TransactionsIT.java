package vn.kakeibo.e2e;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

class TransactionsIT {
    @Test
    void expenseCrudReversesPreviousBalanceAndPreservesDecimalPrecision() {
        Api api = Api.newUser();
        long wallet = api.account("Chi tiêu", "1000.10");
        long id = api.transaction(Map.of("account_id", wallet, "amount", "10.25",
            "transaction_type", "expense", "raw_description", "Bữa trưa"));
        String path = TRANSACTIONS + "/" + id;
        money(expect(api.get(path), 200), "amount", "10.25");
        api.balance(wallet, "989.85");
        expect(api.patch(path, Map.of("amount", "20.35", "clean_description", "Ăn trưa")), 200);
        var persisted = expect(api.get(path), 200);
        money(persisted, "amount", "20.35");
        assertEquals("Ăn trưa", persisted.jsonPath().getString("clean_description"));
        api.balance(wallet, "979.75");
        money(expect(api.get("/api/v1/overview"), 200), "current_balance", "979.75");
        assertEquals("", expect(api.delete(path), 204).asString());
        api.balance(wallet, "1000.10");
        expect(api.get(path), 404);
        expect(api.delete(path), 404);
    }

    @Test
    void transferUpdatesBothWalletsWithoutCountingAsIncomeOrExpense() {
        Api api = Api.newUser();
        long source = api.account("Nguồn", "1000");
        long destination = api.account("Đích", "200");
        long id = api.transaction(Map.of("account_id", source, "to_account_id", destination,
            "amount", "125.25", "transaction_type", "transfer"));
        api.balance(source, "874.75");
        api.balance(destination, "325.25");
        var overview = expect(api.get("/api/v1/overview"), 200);
        money(overview, "current_balance", "1200");
        money(overview, "monthly_income", "0");
        money(overview, "monthly_expense", "0");
        expect(api.patch(TRANSACTIONS + "/" + id, Map.of("amount", "50.10")), 200);
        api.balance(source, "949.90");
        api.balance(destination, "250.10");
        expect(api.delete(TRANSACTIONS + "/" + id), 204);
        api.balance(source, "1000");
        api.balance(destination, "200");
    }

    @Test
    void listUsesStableDateOrderingPaginationAndTypeFilter() {
        Api api = Api.newUser();
        long first = api.transaction(Map.of("amount", "1", "transaction_type", "income",
            "transaction_date", "2025-01-01T10:00:00Z"));
        long second = api.transaction(Map.of("amount", "2", "transaction_type", "income",
            "transaction_date", "2025-01-01T10:00:00Z"));
        api.transaction(Map.of("amount", "3", "transaction_type", "expense",
            "transaction_date", "2025-01-02T10:00:00Z"));
        var page = expect(api.get(TRANSACTIONS + "?transaction_type=income&limit=1&offset=0"), 200);
        assertEquals(2, page.jsonPath().getInt("total"));
        assertEquals(1, page.jsonPath().getInt("limit"));
        assertEquals(0, page.jsonPath().getInt("offset"));
        assertEquals(1, page.jsonPath().getList("items").size());
        assertEquals(second, page.jsonPath().getLong("items[0].id"));
        var next = expect(api.get(TRANSACTIONS + "?transaction_type=income&limit=1&offset=1"), 200);
        assertEquals(first, next.jsonPath().getLong("items[0].id"));
        var empty = expect(api.get(TRANSACTIONS + "?offset=99"), 200);
        assertTrue(empty.jsonPath().getList("items").isEmpty());
        assertEquals(3, empty.jsonPath().getInt("total"));
    }

    @Test
    void overviewIncludesOnlyCurrentUtcMonthAndIncomeUpdatesBalance() {
        Api api = Api.newUser();
        long wallet = api.account("Tháng", "0");
        LocalDate month = LocalDate.now(ZoneOffset.UTC).withDayOfMonth(1);
        api.transaction(Map.of("account_id", wallet, "amount", "100.10", "transaction_type", "income",
            "transaction_date", month + "T00:00:00Z"));
        api.transaction(Map.of("account_id", wallet, "amount", "10.05", "transaction_type", "expense",
            "transaction_date", month + "T00:00:00Z"));
        api.transaction(Map.of("account_id", wallet, "amount", "50", "transaction_type", "expense",
            "transaction_date", month.minusDays(1) + "T23:59:59Z"));
        var overview = expect(api.get("/api/v1/overview"), 200);
        money(overview, "monthly_income", "100.10");
        money(overview, "monthly_expense", "10.05");
        money(overview, "current_balance", "40.05");
        api.balance(wallet, "40.05");
    }

    @ParameterizedTest
    @ValueSource(strings = {"0", "-1", "0.001", "10000000000000.00"})
    void invalidAmountsDoNotCreateTransactions(String amount) {
        Api api = Api.newUser();
        expect(api.post(TRANSACTIONS, Map.of("amount", amount, "transaction_type", "expense")), 422);
        assertEquals(0, expect(api.get(TRANSACTIONS), 200).jsonPath().getInt("total"));
    }

    @Test
    void invalidTransferArchivedWalletAndMalformedPatchesAreRejected() {
        Api api = Api.newUser();
        long wallet = api.account("Ví", "100");
        expect(api.post(TRANSACTIONS, Map.of("account_id", wallet, "to_account_id", wallet,
            "amount", "10", "transaction_type", "transfer")), 422);
        long id = api.transaction(Map.of("account_id", wallet, "amount", "1", "transaction_type", "expense"));
        expect(api.patch(TRANSACTIONS + "/" + id, Map.of()), 422);
        expect(api.patch(TRANSACTIONS + "/" + id, "{\"amount\":null}"), 422);
        expect(api.patch(TRANSACTIONS + "/" + id, Map.of("user_id", api.userId)), 422);
        expect(api.post(TRANSACTIONS, Map.of("amount", "1", "transaction_type", "expense",
            "transaction_date", "2026-01-01T10:00:00")), 422);
        expect(api.patch(MANAGE + "accounts/" + wallet, Map.of("is_archived", true)), 200);
        expect(api.post(TRANSACTIONS, Map.of("account_id", wallet, "amount", "1",
            "transaction_type", "expense")), 422);
        api.balance(wallet, "99");
    }
}
