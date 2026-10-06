package vn.kakeibo.e2e.support;

import io.restassured.RestAssured;
import io.restassured.config.HttpClientConfig;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import io.restassured.specification.RequestSpecification;
import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

/** HTTP-only fixtures: no privileged DB writes or mocked authentication. */
public final class Api {
    public static final String BASE = required("API_BASE_URL", "http://api:8000");
    public static final String SUPABASE = required("SUPABASE_URL", "http://gateway:8000");
    public static final String ANON = required("SUPABASE_ANON_KEY", null);
    public static final String MANAGE = "/api/v1/manage/";
    public static final String TRANSACTIONS = "/api/v1/transactions";

    private final String token;
    public final String userId;

    private Api(String token, String userId) {
        this.token = token;
        this.userId = userId;
    }

    private static String required(String name, String expected) {
        if (!"true".equals(System.getenv("GITHUB_ACTIONS"))) {
            throw new IllegalStateException("Run Backend Java E2E on GitHub Actions, inside Docker.");
        }
        String value = System.getenv(name);
        if (value == null || value.isBlank() || (expected != null && !expected.equals(value))) {
            throw new IllegalStateException("Missing or unsafe test configuration: " + name);
        }
        return value;
    }

    public static RequestSpecification request(String base) {
        return RestAssured.given().baseUri(base).contentType(ContentType.JSON)
            .config(RestAssured.config().httpClient(HttpClientConfig.httpClientConfig()
                .setParam("http.connection.timeout", 10000)
                .setParam("http.socket.timeout", 20000)));
    }

    public static Api newUser() {
        String email = "e2e-" + UUID.randomUUID() + "@example.com";
        String password = "E2e!" + UUID.randomUUID();
        Response signup = request(SUPABASE).header("apikey", ANON)
            .body(Map.of("email", email, "password", password))
            .post("/auth/v1/signup");
        // Never log auth response bodies: they contain access/refresh tokens.
        assertEquals(200, signup.statusCode(), "Supabase signup failed");
        Response login = request(SUPABASE).header("apikey", ANON)
            .body(Map.of("email", email, "password", password))
            .post("/auth/v1/token?grant_type=password");
        assertEquals(200, login.statusCode(), "Supabase password login failed");
        String token = login.jsonPath().getString("access_token");
        String userId = login.jsonPath().getString("user.id");
        assertNotNull(token);
        assertNotNull(userId);
        return new Api(token, userId);
    }

    public RequestSpecification authenticated() {
        return request(BASE).auth().oauth2(token);
    }

    public RequestSpecification databaseApi() {
        return request(SUPABASE).header("apikey", ANON).auth().oauth2(token);
    }

    public Response get(String path) { return authenticated().get(path); }
    public Response post(String path, Object body) { return authenticated().body(body).post(path); }
    public Response patch(String path, Object body) { return authenticated().body(body).patch(path); }
    public Response delete(String path) { return authenticated().delete(path); }

    public static Response expect(Response response, int status) {
        assertEquals(status, response.statusCode(), () -> "API response: " + response.asString());
        return response;
    }

    public long create(String resource, Object body) {
        return expect(post(MANAGE + resource, body), 201).jsonPath().getLong("id");
    }

    public long account(String name, String balance) {
        return create("accounts", Map.of("name", name, "account_type", "cash", "balance", balance));
    }

    public long transaction(Object body) {
        return expect(post(TRANSACTIONS, body), 201).jsonPath().getLong("id");
    }

    public void balance(long accountId, String expected) {
        money(expect(get(MANAGE + "accounts/" + accountId), 200), "balance", expected);
    }

    public static void money(Response response, String field, String expected) {
        assertEquals(0, new BigDecimal(expected).compareTo(
            new BigDecimal(response.jsonPath().getString(field))), field);
    }
}
