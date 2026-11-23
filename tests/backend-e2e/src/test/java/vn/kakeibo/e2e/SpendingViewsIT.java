package vn.kakeibo.e2e;

import io.restassured.response.Response;
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

    private static void spend(Api user) {
        long wallet = user.account("Chi tiêu", "100");
        user.transaction(Map.of("account_id", wallet, "amount", "5", "transaction_type", "expense"));
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
        for (String view : VIEWS) {
            List<String> owners = expect(owner.databaseApi().get("/rest/v1/" + view + "?select=user_id"), 200)
                .jsonPath().getList("user_id");
            assertTrue(owners.stream().allMatch(owner.userId::equals), () -> view + " leaks rows: " + owners);
        }
        List<String> summary = expect(owner.databaseApi().get("/rest/v1/v_kakeibo_monthly_summary?select=user_id"), 200)
            .jsonPath().getList("user_id");
        assertEquals(List.of(owner.userId), summary);
    }
}
