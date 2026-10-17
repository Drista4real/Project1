package vn.kakeibo.e2e;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

/** Real authentication, HTTP, parser and database; no model or cloud credentials. */
class IngestionIT {
    private static final String INGEST = "/api/v1/ingestion/text";

    @Test
    void analysisRequiresAValidUserToken() {
        var body = Map.of("text", "ăn trưa 65k");
        var missing = expect(request(BASE).body(body).post(INGEST), 401);
        assertEquals("Bearer", missing.header("WWW-Authenticate"));
        expect(request(BASE).header("Authorization", "Bearer invalid-token")
            .body(body).post(INGEST), 401);
    }

    @Test
    void analysisIsReadOnlyUntilUserExplicitlySavesAndCanCorrectTheDraft() {
        Api api = Api.newUser();
        Api other = Api.newUser();
        long wallet = api.account("Nhập liệu", "100000");
        var draft = expect(api.post(INGEST, Map.of("text", "ăn trưa 65k")), 200);
        assertEquals(1, draft.jsonPath().getList("drafts").size());
        money(draft, "drafts[0].amount", "65000");
        assertEquals("expense", draft.jsonPath().getString("drafts[0].transaction_type"));
        assertFalse(draft.jsonPath().getMap("drafts[0]").containsKey("id"));
        assertEquals(0, expect(api.get(TRANSACTIONS), 200).jsonPath().getInt("total"));
        api.balance(wallet, "100000");

        // Review is allowed to change the extracted amount before saving.
        long id = api.transaction(Map.of("account_id", wallet, "amount", "60000",
            "transaction_type", draft.jsonPath().getString("drafts[0].transaction_type"),
            "raw_description", draft.jsonPath().getString("drafts[0].text")));
        api.balance(wallet, "40000");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_expense", "60000");
        money(expect(api.get(TRANSACTIONS + "/" + id), 200), "amount", "60000");
        expect(other.get(TRANSACTIONS + "/" + id), 404);
        expect(other.patch(TRANSACTIONS + "/" + id, Map.of("amount", "1")), 404);
        expect(other.delete(TRANSACTIONS + "/" + id), 404);
        api.balance(wallet, "40000");
        expect(api.delete(TRANSACTIONS + "/" + id), 204);
        api.balance(wallet, "100000");
    }

    @Test
    void separateDraftsAndAmbiguousMoneyNeverPersistImplicitly() {
        Api api = Api.newUser();
        var split = expect(api.post(INGEST, Map.of("text", "ăn trưa 65k; trà sữa 35k")), 200);
        assertEquals(2, split.jsonPath().getList("drafts").size());
        money(split, "drafts[0].amount", "65000");
        money(split, "drafts[1].amount", "35000");
        var ambiguous = expect(api.post(INGEST, Map.of("text", "cà phê 40k giảm còn 20k")), 200);
        assertNull(ambiguous.jsonPath().get("drafts[0].amount"));
        assertFalse(ambiguous.jsonPath().getList("drafts[0].warnings").isEmpty());
        assertEquals(0, expect(api.get(TRANSACTIONS), 200).jsonPath().getInt("total"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "   ", ";;;", "ăn 1k;ăn 2k;ăn 3k;ăn 4k;ăn 5k;ăn 6k"})
    void rejectedInputLeavesFinancialStateUntouched(String text) {
        Api api = Api.newUser();
        long wallet = api.account("Giới hạn", "100000");
        expect(api.post(INGEST, Map.of("text", text)), 422);
        expect(api.post(INGEST, Map.of("text", "x".repeat(2001))), 422);
        assertEquals(0, expect(api.get(TRANSACTIONS), 200).jsonPath().getInt("total"));
        api.balance(wallet, "100000");
    }
}
