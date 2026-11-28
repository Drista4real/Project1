package vn.kakeibo.e2e;

import io.restassured.response.Response;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

/** B14: the spending views read straight through PostgREST. */
class SpendingViewsIT {
    private static final List<String> VIEWS = List.of(
        "v_current_month_spending_by_category",
        "v_kakeibo_monthly_summary",
        "v_monthly_budget_progress");

    /** A category, its budget for this month and an expense in it, so every view has a row. */
    private static void spend(Api user) {
        long wallet = user.account("Chi tiêu", "100");
        long category = user.create("categories", Map.of("name", "Ăn uống B14", "pillar", "needs"));
        // The views compare against the database's current month, which runs in UTC.
        String month = LocalDate.now(ZoneOffset.UTC).withDayOfMonth(1).toString();
        user.create("budgets", Map.of("month_year", month, "limit_amount", "500", "category_id", category));
        user.transaction(Map.of("account_id", wallet, "amount", "5", "transaction_type", "expense",
            "category_id", category));
    }

    private static List<String> owners(Api user, String view) {
        return expect(user.databaseApi().get("/rest/v1/" + view + "?select=user_id"), 200)
            .jsonPath().getList("user_id");
    }

    @Test
    void anonCannotReadTheSpendingViews() {
        spend(Api.newUser());
        for (String view : VIEWS) {
            Response response = request(SUPABASE).header("apikey", ANON).auth().oauth2(ANON)
                .get("/rest/v1/" + view);
            expect(response, 401);
            assertEquals("42501", response.jsonPath().getString("code"), view);
        }
    }

    @Test
    void aSignedInUserOnlySeesTheirOwnRows() {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        spend(owner);
        spend(other);
        // assertAll reports every view, not only the first one that leaks.
        assertAll(VIEWS.stream().map(view -> () -> {
            List<String> rows = owners(owner, view);
            assertFalse(rows.isEmpty(), () -> view + " returns no row for its own user");
            assertFalse(rows.contains(other.userId), () -> view + " leaks the other user's rows: " + rows);
            assertTrue(rows.stream().allMatch(owner.userId::equals), () -> view + " leaks rows: " + rows);
        }));
    }

    @Test
    void aSignedInUserCannotWriteThroughTheViews() {
        Api owner = Api.newUser();
        spend(owner);
        String mine = "?user_id=eq." + owner.userId;
        for (String view : VIEWS) {
            String path = "/rest/v1/" + view;
            List<String> before = owners(owner, view);
            for (Response response : List.of(
                    owner.databaseApi().body(Map.of("user_id", owner.userId)).post(path),
                    owner.databaseApi().body(Map.of("user_id", owner.userId)).patch(path + mine),
                    owner.databaseApi().delete(path + mine))) {
                // Postgres refuses a write into an aggregate view while rewriting the query, before it
                // checks privileges, so PostgREST answers 500 with 55000 even though authenticated only
                // holds SELECT. Any other 500 is a real failure.
                expect(response, 500);
                assertEquals("55000", response.jsonPath().getString("code"), () -> view + ": " + response.asString());
            }
            assertEquals(before, owners(owner, view), view);
        }
    }
}
