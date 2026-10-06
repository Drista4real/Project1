package vn.kakeibo.e2e;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

class AuthIT {
    @Test
    void healthIsPublic() {
        assertEquals("ok", expect(request(BASE).get("/health"), 200).jsonPath().getString("status"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"/api/v1/accounts", "/api/v1/categories", "/api/v1/overview",
        "/api/v1/transactions", "/api/v1/manage/resources", "/api/v1/manage/profile/me"})
    void protectedReadsRejectMissingAndInvalidTokens(String path) {
        var missing = expect(request(BASE).get(path), 401);
        assertEquals("Bearer", missing.header("WWW-Authenticate"));
        expect(request(BASE).header("Authorization", "Bearer invalid-token").get(path), 401);
    }

    @Test
    void signupCreatesProfileAndDefaultWalletThroughDatabaseTrigger() {
        Api api = Api.newUser();
        var profile = expect(api.get(MANAGE + "profile/me"), 200);
        assertEquals(api.userId, profile.jsonPath().getString("id"));
        money(profile, "current_balance", "0");
        assertEquals(1, expect(api.get("/api/v1/accounts"), 200).jsonPath().getList("$").size());
        assertFalse(expect(api.get("/api/v1/categories"), 200).jsonPath().getList("$").isEmpty());
        assertEquals(14, expect(api.get(MANAGE + "resources"), 200).jsonPath().getList("$").size());
    }

    @Test
    void writesAlsoRequireAuthentication() {
        expect(request(BASE).body(Map.of("amount", "1", "transaction_type", "expense"))
            .post(TRANSACTIONS), 401);
        expect(request(BASE).body(Map.of("amount", "2")).patch(TRANSACTIONS + "/1"), 401);
        expect(request(BASE).delete(TRANSACTIONS + "/1"), 401);
        expect(request(BASE).body(Map.of("name", "Tag")).post(MANAGE + "tags"), 401);
        expect(request(BASE).body(Map.of("name", "Tag")).patch(MANAGE + "tags/1"), 401);
        expect(request(BASE).delete(MANAGE + "tags/1"), 401);
    }
}
