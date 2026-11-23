package vn.kakeibo.e2e;

import io.restassured.response.Response;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

/** B13: SECURITY DEFINER functions reached straight through PostgREST. */
class SecurityDefinerIT {
    private static final String ENVELOPE = "/rest/v1/rpc/validate_envelope_capacity";
    private static final String REBALANCE = "/rest/v1/rpc/rebalance_plan";

    private static Map<String, Object> envelope(String userId) {
        return Map.of("p_user_id", userId, "p_month", "2026-11-01");
    }

    /** The publishable key alone, as a signed-out client sends it. */
    private static Response asAnon(String path, Object body) {
        return request(SUPABASE).header("apikey", ANON).auth().oauth2(ANON).body(body).post(path);
    }

    private static void permissionDenied(Response response) {
        expect(response, 401);
        assertEquals("42501", response.jsonPath().getString("code"));
        // The grant, not the function body, must stop the call.
        assertTrue(response.jsonPath().getString("message").startsWith("permission denied for function"),
            () -> "Unexpected error: " + response.asString());
    }

    @Test
    void anonCannotCallTheSecurityDefinerRpcs() {
        permissionDenied(asAnon(ENVELOPE, envelope(UUID.randomUUID().toString())));
        permissionDenied(asAnon(REBALANCE, Map.of(
            "p_plan_id", 1, "p_expected_version", 1, "p_allocations", "[]",
            "p_purchase", "{}", "p_idempotency_key", UUID.randomUUID().toString())));
    }

    @Test
    void aUserCannotCheckAnotherUsersEnvelopes() {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        Response response = expect(other.databaseApi().body(envelope(owner.userId)).post(ENVELOPE), 403);
        assertEquals("42501", response.jsonPath().getString("code"));
    }

    @Test
    void aUserCanStillCheckTheirOwnEnvelopes() {
        Api owner = Api.newUser();
        expect(owner.databaseApi().body(envelope(owner.userId)).post(ENVELOPE), 204);
    }
}
