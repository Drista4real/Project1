package vn.kakeibo.e2e;

import io.restassured.response.Response;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

/** Real disposable Auth, SMTP inbox, RLS and backend. Never logs OTP or sessions. */
class EmailAndGuestAuthIT {
    private static Response authPost(String path, Object body) {
        return request(SUPABASE).header("apikey", ANON).body(body).post("/auth/v1/" + path);
    }

    private static void authStatus(Response response, int expected) {
        assertEquals(expected, response.statusCode(), "Unexpected Auth response status");
    }

    private static String waitForCode(String recipient, String excludedId) throws Exception {
        long deadline = System.nanoTime() + java.time.Duration.ofSeconds(20).toNanos();
        while (System.nanoTime() < deadline) {
            Response inbox = request("http://mailpit:8025").get("/api/v1/messages?limit=100");
            assertEquals(200, inbox.statusCode(), "Inbox unavailable");
            List<Map<String, Object>> messages = inbox.jsonPath().getList("messages");
            for (var message : messages) {
                String id = (String) message.get("ID");
                if (id.equals(excludedId)) continue;
                @SuppressWarnings("unchecked")
                var recipients = (List<Map<String, Object>>) message.get("To");
                if (recipients.stream().noneMatch(to -> recipient.equals(to.get("Address")))) continue;
                Response detail = request("http://mailpit:8025").get("/api/v1/message/" + id);
                assertEquals(200, detail.statusCode(), "Message unavailable");
                String content = detail.jsonPath().getString("Text") + " " + detail.jsonPath().getString("HTML");
                var matcher = Pattern.compile("(?<!\\d)(\\d{6})(?!\\d)").matcher(content);
                assertTrue(matcher.find(), "Email template must contain a six-digit code");
                return id + ":" + matcher.group(1);
            }
            Thread.sleep(200);
        }
        throw new AssertionError("No verification email arrived in the disposable inbox");
    }

    @Test
    void emailOtpAndRecoveryUseRealMailAndRejectReplay() throws Exception {
        String email = "otp-" + UUID.randomUUID() + "@example.com";
        String password = "Initial!" + UUID.randomUUID();
        authStatus(authPost("signup", Map.of("email", email, "password", password)), 200);
        authStatus(authPost("otp", Map.of("email", email, "create_user", false)), 200);
        String received = waitForCode(email, "");
        String messageId = received.split(":", 2)[0];
        String otp = received.split(":", 2)[1];
        Api signedIn = Api.fromSession(authPost("verify", Map.of("email", email, "token", otp, "type", "email")));
        assertEquals(signedIn.userId, expect(signedIn.get(MANAGE + "profile/me"), 200).jsonPath().getString("id"));
        authStatus(authPost("verify", Map.of("email", email, "token", otp, "type", "email")), 403);
        // A separate endpoint and verification type establish the recovery session.
        Thread.sleep(1100); // Isolated test-only SMTP throttle, not the app's timer.
        authStatus(authPost("recover", Map.of("email", email)), 200);
        String recoveryCode = waitForCode(email, messageId).split(":", 2)[1];
        Api recovery = Api.fromSession(authPost("verify", Map.of("email", email, "token", recoveryCode, "type", "recovery")));
        String replacement = "Replacement!" + UUID.randomUUID();
        authStatus(recovery.databaseApi().body(Map.of("password", replacement)).put("/auth/v1/user"), 200);
        authStatus(recovery.databaseApi().post("/auth/v1/logout?scope=local"), 204);
        authStatus(authPost("token?grant_type=password", Map.of("email", email, "password", password)), 400);
        Api updated = Api.fromSession(authPost("token?grant_type=password", Map.of("email", email, "password", replacement)));
        assertEquals(signedIn.userId, updated.userId);
        authStatus(authPost("verify", Map.of("email", email, "token", recoveryCode, "type", "recovery")), 403);
    }

    @Test
    void guestsAreIsolatedAndLinkingKeepsRecordIdsAndBalances() {
        Response session = authPost("signup", Map.of());
        Api guest = Api.fromSession(session);
        assertTrue(session.jsonPath().getBoolean("user.is_anonymous"));
        Api otherGuest = Api.fromSession(authPost("signup", Map.of()));
        Api regular = Api.newUser();
        long wallet = expect(guest.get("/api/v1/accounts"), 200).jsonPath().getLong("[0].id");
        assertEquals(1, expect(guest.get("/api/v1/accounts"), 200).jsonPath().getList("$").size());
        long transaction = guest.transaction(Map.of("account_id", wallet, "amount", "25.50", "transaction_type", "income", "raw_description", "Guest income"));
        guest.balance(wallet, "25.50");
        expect(otherGuest.get(MANAGE + "accounts/" + wallet), 404);
        expect(regular.get(MANAGE + "accounts/" + wallet), 404);
        var hidden = otherGuest.databaseApi().get("/rest/v1/transactions?id=eq." + transaction);
        assertEquals(200, hidden.statusCode());
        assertTrue(hidden.jsonPath().getList("$").isEmpty());

        Response restored = authPost("token?grant_type=refresh_token", Map.of("refresh_token", session.jsonPath().getString("refresh_token")));
        Api refreshed = Api.fromSession(restored);
        assertEquals(guest.userId, refreshed.userId);
        String email = "linked-" + UUID.randomUUID() + "@example.com";
        // This existing stack auto-confirms email; Flutter separately tests the OTP link flow.
        Response linked = refreshed.databaseApi().body(Map.of("email", email)).put("/auth/v1/user");
        authStatus(linked, 200);
        assertFalse(linked.jsonPath().getBoolean("is_anonymous"));
        assertEquals(guest.userId, linked.jsonPath().getString("id"));
        assertEquals(email, expect(refreshed.get(MANAGE + "profile/me"), 200).jsonPath().getString("email"));
        assertEquals(1, expect(refreshed.get("/api/v1/accounts"), 200).jsonPath().getList("$").size());
        expect(refreshed.get(TRANSACTIONS + "/" + transaction), 200);
        refreshed.balance(wallet, "25.50");
        expect(otherGuest.get(TRANSACTIONS + "/" + transaction), 404);
    }
}
