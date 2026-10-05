package vn.kakeibo.e2e;

import java.util.Map;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

class ManagementIT {
    record CrudCase(String resource, Map<String, Object> input, String field, Object updated) {
        @Override public String toString() { return resource; }
    }

    static Stream<CrudCase> resources() {
        return Stream.of(
            new CrudCase("accounts", Map.of("name", "Ví", "account_type", "bank"), "name", "Ví mới"),
            new CrudCase("categories", Map.of("name", "Ăn uống", "pillar", "needs"), "name", "Ăn trưa"),
            new CrudCase("tags", Map.of("name", "Công việc"), "color", "#123456"),
            new CrudCase("budgets", Map.of("month_year", "2026-01-01", "limit_amount", "500"), "alert_threshold_percent", 75),
            new CrudCase("saving_goals", Map.of("name", "Du lịch", "target_amount", "1000"), "name", "Du lịch hè"),
            new CrudCase("debts_loans", Map.of("type", "debt", "person_name", "An", "amount", "500"), "status", "partial"),
            new CrudCase("recurring_transactions", Map.of("amount", "100", "transaction_type", "expense",
                "description", "Thuê nhà", "frequency", "monthly", "start_date", "2026-01-01",
                "next_execution_date", "2026-02-01"), "description", "Tiền nhà"),
            new CrudCase("cashflow_forecasts", Map.of("forecast_date", "2026-02-01", "predicted_balance", "100"), "risk_level", "warning"),
            new CrudCase("cashflow_alerts", Map.of("alert_type", "low_balance", "title", "Số dư thấp", "message", "Kiểm tra ví"), "is_read", true),
            new CrudCase("ai_consultations", Map.of("user_query", "Tiết kiệm?", "ai_recommendation", "Lập ngân sách"), "user_query", "Ngân sách tháng?"),
            new CrudCase("ai_chat_sessions", Map.of("title", "Tư vấn"), "title", "Tư vấn tháng")
        );
    }

    @ParameterizedTest(name = "CRUD and owner isolation: {0}")
    @MethodSource("resources")
    void managementCrudPersistsEditsAndHidesOtherUsers(CrudCase test) {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        String collection = MANAGE + test.resource();
        long id = owner.create(test.resource(), test.input());
        String path = collection + "/" + id;
        assertEquals(owner.userId, expect(owner.get(path), 200).jsonPath().getString("user_id"));
        assertTrue(expect(owner.get(collection), 200).jsonPath().getList("items.id", Long.class).contains(id));
        assertFalse(expect(other.get(collection), 200).jsonPath().getList("items.id", Long.class).contains(id));
        expect(other.get(path), 404);
        expect(other.patch(path, Map.of(test.field(), test.updated())), 404);
        expect(other.delete(path), 404);
        expect(owner.patch(path, Map.of(test.field(), test.updated())), 200);
        assertEquals(test.updated().toString(), expect(owner.get(path), 200).jsonPath().getString(test.field()));
        assertEquals("", expect(owner.delete(path), 204).asString());
        expect(owner.get(path), 404);
        assertFalse(expect(owner.get(collection), 200).jsonPath().getList("items.id", Long.class).contains(id));
    }

    @Test
    void profileEditsPersistButIdentityAndBalanceCannotBeForged() {
        Api api = Api.newUser();
        String path = MANAGE + "profile/me";
        expect(api.patch(path, Map.of("full_name", "Nguyễn An", "dark_mode_enabled", true)), 200);
        var result = expect(api.get(path), 200);
        assertEquals("Nguyễn An", result.jsonPath().getString("full_name"));
        assertTrue(result.jsonPath().getBoolean("dark_mode_enabled"));
        expect(api.patch(path, Map.of("current_balance", "999999")), 422);
        expect(api.patch(path, Map.of("id", api.userId)), 422);
        expect(api.delete(path), 405);
    }

    @Test
    void walletBalanceAndInclusionEditsSynchronizeProfileTotal() {
        Api api = Api.newUser();
        long first = api.account("Cash", "100.25");
        long second = api.account("Savings", "200.50");
        money(expect(api.get(MANAGE + "profile/me"), 200), "current_balance", "300.75");
        expect(api.patch(MANAGE + "accounts/" + first, Map.of("balance", "150.35")), 200);
        money(expect(api.get("/api/v1/overview"), 200), "current_balance", "350.85");
        expect(api.patch(MANAGE + "accounts/" + second, Map.of("is_included_in_total", false)), 200);
        money(expect(api.get("/api/v1/overview"), 200), "current_balance", "150.35");
        expect(api.delete(MANAGE + "accounts/" + first), 204);
        money(expect(api.get(MANAGE + "profile/me"), 200), "current_balance", "0");
    }

    @Test
    void usedWalletAndCategoryCannotBeDeletedUntilTransactionIsRemoved() {
        Api api = Api.newUser();
        long wallet = api.account("Ví", "100");
        long category = api.create("categories", Map.of("name", "Ăn uống", "is_income", false));
        long transaction = api.transaction(Map.of("account_id", wallet, "category_id", category,
            "amount", "10", "transaction_type", "expense"));
        expect(api.delete(MANAGE + "accounts/" + wallet), 409);
        expect(api.delete(MANAGE + "categories/" + category), 409);
        expect(api.patch(MANAGE + "categories/" + category, Map.of("is_income", true)), 409);
        expect(api.delete(TRANSACTIONS + "/" + transaction), 204);
        expect(api.delete(MANAGE + "categories/" + category), 204);
        expect(api.delete(MANAGE + "accounts/" + wallet), 204);
        money(expect(api.get("/api/v1/overview"), 200), "current_balance", "0");
    }

    @Test
    void systemCategoriesAreReadOnlyAndCategoryCyclesAreRejected() {
        Api api = Api.newUser();
        long system = expect(api.get("/api/v1/categories"), 200).jsonPath().getLong("[0].id");
        expect(api.patch(MANAGE + "categories/" + system, Map.of("name", "Changed")), 403);
        expect(api.delete(MANAGE + "categories/" + system), 403);
        long parent = api.create("categories", Map.of("name", "Cha"));
        long child = api.create("categories", Map.of("name", "Con", "parent_id", parent));
        expect(api.patch(MANAGE + "categories/" + parent, Map.of("parent_id", child)), 422);
        expect(api.post(TRANSACTIONS, Map.of("category_id", child, "transaction_type", "income", "amount", "1")), 422);
    }

    @Test
    void tagLinksUseCompositeKeysRejectDuplicatesAndCascadeOnTagDeletion() {
        Api api = Api.newUser();
        long tag = api.create("tags", Map.of("name", "Thực phẩm"));
        long replacement = api.create("tags", Map.of("name", "Gia đình"));
        long transaction = api.transaction(Map.of("amount", "5", "transaction_type", "expense"));
        Map<String, Object> link = Map.of("transaction_id", transaction, "tag_id", tag);
        String path = MANAGE + "transaction_tags/" + transaction + ":" + tag;
        expect(api.post(MANAGE + "transaction_tags", link), 201);
        expect(api.get(path), 200);
        expect(api.post(MANAGE + "transaction_tags", link), 409);
        expect(api.patch(path, Map.of("tag_id", replacement)), 200);
        expect(api.get(path), 404);
        String changed = MANAGE + "transaction_tags/" + transaction + ":" + replacement;
        expect(api.get(changed), 200);
        expect(api.delete(changed), 204);
        expect(api.post(MANAGE + "transaction_tags", link), 201);
        expect(api.delete(MANAGE + "tags/" + tag), 204);
        expect(api.get(path), 404);
        expect(api.get(TRANSACTIONS + "/" + transaction), 200);
    }

    @Test
    void chatMessagesFollowSessionOwnershipAndCascadeOnSessionDeletion() {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        long session = owner.create("ai_chat_sessions", Map.of("title", "Tư vấn"));
        Map<String, Object> message = Map.of("session_id", session, "sender", "user", "content", "Xin chào");
        long id = owner.create("ai_chat_messages", message);
        String path = MANAGE + "ai_chat_messages/" + id;
        expect(other.post(MANAGE + "ai_chat_messages", message), 422);
        expect(other.get(path), 404);
        expect(other.patch(path, Map.of("content", "Changed")), 404);
        expect(other.delete(path), 404);
        assertEquals(0, expect(other.get(MANAGE + "ai_chat_messages"), 200).jsonPath().getInt("total"));
        expect(owner.patch(path, Map.of("content", "Chào bạn")), 200);
        assertEquals("Chào bạn", expect(owner.get(path), 200).jsonPath().getString("content"));
        expect(owner.delete(path), 204);
        long cascaded = owner.create("ai_chat_messages", message);
        expect(owner.delete(MANAGE + "ai_chat_sessions/" + session), 204);
        expect(owner.get(MANAGE + "ai_chat_messages/" + cascaded), 404);
    }

    @ParameterizedTest
    @ValueSource(strings = {"?limit=0", "?limit=101", "?offset=-1"})
    void paginationBoundsAreValidated(String query) {
        Api api = Api.newUser();
        expect(api.get(TRANSACTIONS + query), 422);
        expect(api.get(MANAGE + "tags" + query), 422);
    }

    @Test
    void crossFieldValidationRejectsInvalidFinancialRecords() {
        Api api = Api.newUser();
        expect(api.post(MANAGE + "budgets", Map.of("month_year", "2026-01-02", "limit_amount", "50")), 422);
        expect(api.post(MANAGE + "debts_loans", Map.of("type", "debt", "person_name", "An",
            "amount", "10", "paid_amount", "11")), 422);
        expect(api.post(MANAGE + "cashflow_forecasts", Map.of("forecast_date", "2026-01-01",
            "predicted_balance", "10", "lower_bound", "20", "upper_bound", "5")), 422);
        long tag = api.create("tags", Map.of("name", "Test"));
        expect(api.patch(MANAGE + "tags/" + tag, Map.of()), 422);
        expect(api.patch(MANAGE + "tags/" + tag, "{\"name\":null}"), 422);
        expect(api.post(MANAGE + "tags", Map.of("name", "Forged", "user_id", api.userId)), 422);
    }
}
