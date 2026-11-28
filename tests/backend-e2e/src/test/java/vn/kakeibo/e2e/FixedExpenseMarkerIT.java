package vn.kakeibo.e2e;

import io.restassured.response.Response;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

/**
 * The fixed expense marker, written straight through PostgREST so the
 * database guard is proven on its own, without the API's own validation.
 */
class FixedExpenseMarkerIT {
    private static final String REST = "/rest/v1/transactions";
    private static final String MARKER = "fixed_expense_plan_id";

    private static long plan(Api api) {
        return expect(api.post("/api/v1/budget-plans", Map.of(
            "total_income", "8000000.00",
            "duration_days", 30,
            "savings_target", "0.00",
            "fixed_expenses", "3000000.00"
        )), 201).jsonPath().getLong("plan.id");
    }

    private static Map<String, Object> row(Api api, long wallet, String type, Long plan) {
        Map<String, Object> row = new HashMap<>();
        row.put("user_id", api.userId);
        row.put("account_id", wallet);
        row.put("amount", "2500000");
        row.put("transaction_type", type);
        row.put(MARKER, plan);
        return row;
    }

    private static Response insert(Api api, Map<String, Object> row) {
        return api.databaseApi().header("Prefer", "return=representation").body(row).post(REST);
    }

    private static void rejected(Response response) {
        expect(response, 400);
        assertEquals("23514", response.jsonPath().getString("code"));
    }

    @Test
    void anOwnerMarksAnExpenseWithTheirOwnPlan() {
        Api owner = Api.newUser();
        long plan = plan(owner);
        long wallet = owner.account("Ví", "5000000");
        Response created = expect(insert(owner, row(owner, wallet, "expense", plan)), 201);
        assertEquals(plan, created.jsonPath().getLong("[0]." + MARKER));
    }

    @Test
    void anotherUsersPlanIsRefusedOnInsertAndUpdate() {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        long foreignPlan = plan(owner);
        long wallet = other.account("Ví", "5000000");
        rejected(insert(other, row(other, wallet, "expense", foreignPlan)));

        long transaction = other.transaction(Map.of(
            "account_id", wallet, "amount", "10", "transaction_type", "expense"));
        rejected(other.databaseApi().body(Map.of(MARKER, foreignPlan))
            .patch(REST + "?id=eq." + transaction));
    }

    @Test
    void onlyAnExpenseCanBeMarked() {
        Api owner = Api.newUser();
        long plan = plan(owner);
        long wallet = owner.account("Ví", "5000000");
        long target = owner.account("Ví nhận", "0");
        rejected(insert(owner, row(owner, wallet, "income", plan)));
        Map<String, Object> transfer = row(owner, wallet, "transfer", plan);
        transfer.put("to_account_id", target);
        rejected(insert(owner, transfer));

        long marked = expect(insert(owner, row(owner, wallet, "expense", plan)), 201)
            .jsonPath().getLong("[0].id");
        // Turning a marked expense into income must not keep the marker.
        rejected(owner.databaseApi().body(Map.of("transaction_type", "income"))
            .patch(REST + "?id=eq." + marked));
    }

    @Test
    void deletingThePlanClearsTheMarker() {
        Api owner = Api.newUser();
        long plan = plan(owner);
        long wallet = owner.account("Ví", "5000000");
        long marked = expect(insert(owner, row(owner, wallet, "expense", plan)), 201)
            .jsonPath().getLong("[0].id");
        expect(owner.databaseApi().delete("/rest/v1/budget_plans?id=eq." + plan), 204);
        Response after = expect(owner.databaseApi().get(REST + "?id=eq." + marked), 200);
        assertNull(after.jsonPath().get("[0]." + MARKER));
        money(expect(owner.get(TRANSACTIONS + "/" + marked), 200), "amount", "2500000");
    }

    @Test
    void anAnonymousClientCannotWriteAMarker() {
        Api owner = Api.newUser();
        long plan = plan(owner);
        long wallet = owner.account("Ví", "5000000");
        Response response = request(SUPABASE).header("apikey", ANON).auth().oauth2(ANON)
            .body(row(owner, wallet, "expense", plan)).post(REST);
        expect(response, 401);
        assertEquals("42501", response.jsonPath().getString("code"));
        owner.balance(wallet, "5000000");
    }

    @Test
    void theApiAcceptsReturnsAndClearsTheMarker() {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        long plan = plan(owner);
        long wallet = owner.account("Ví", "5000000");
        long transaction = owner.transaction(Map.of(
            "account_id", wallet, "amount", "2500000", "transaction_type", "expense", MARKER, plan));
        String path = TRANSACTIONS + "/" + transaction;
        assertEquals(plan, expect(owner.get(path), 200).jsonPath().getLong(MARKER));

        Map<String, Object> clear = new HashMap<>();
        clear.put(MARKER, null);
        assertNull(expect(owner.patch(path, clear), 200).jsonPath().get(MARKER));

        long otherWallet = other.account("Ví", "100");
        expect(other.post(TRANSACTIONS, Map.of(
            "account_id", otherWallet, "amount", "10", "transaction_type", "expense", MARKER, plan)), 422);
    }
}
