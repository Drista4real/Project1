package vn.kakeibo.e2e;

import io.restassured.response.Response;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

/**
 * The budget engine against a real Postgres.
 *
 * The two guarantees of Ticket A live in the {@code rebalance_plan} function,
 * not in Python: a stale plan version must be refused with HTTP 409, and a
 * repeated idempotency key must return the stored result without writing
 * twice. Neither can be proven with a mocked database, so these tests run
 * against the disposable stack.
 */
class BudgetPlanIT {
    private static final String PLANS = "/api/v1/budget-plans";

    /** A plan whose daily groups add up exactly, so a rebalance can shrink them. */
    private static Map<String, Object> planInput() {
        return Map.of(
            "total_income", "1000000.00",
            "duration_days", 30,
            "savings_target", "0.00",
            "fixed_expenses", "0.00"
        );
    }

    /** The three groups of a freshly created plan, as the rebalance expects them. */
    private static List<Map<String, Object>> allocations(Response created) {
        List<Map<String, Object>> groups = created.jsonPath().getList("plan.groups");
        return groups.stream()
            .map(group -> Map.<String, Object>of(
                "group_key", group.get("group_key"),
                "pillar", group.get("pillar"),
                "daily_amount", group.get("daily_amount")
            ))
            .toList();
    }

    /** The same groups with every daily amount shrunk, so the total goes down. */
    private static List<Map<String, Object>> smallerAllocations(Response created) {
        return allocations(created).stream()
            .map(group -> Map.<String, Object>of(
                "group_key", group.get("group_key"),
                "pillar", group.get("pillar"),
                "daily_amount", "1.00"
            ))
            .toList();
    }

    private static Map<String, Object> rebalanceBody(
            List<Map<String, Object>> allocations, int expectedVersion, String key) {
        return Map.of(
            "expected_version", expectedVersion,
            "current_day", 1,
            "purchase_amount", "0",
            "allocations", allocations,
            "idempotency_key", key
        );
    }

    @Test
    void aPlanIsCreatedWithItsDailyProjection() {
        Api api = Api.newUser();
        Response created = expect(api.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        assertTrue(planId > 0);
        assertEquals(1, created.jsonPath().getInt("plan.plan_version"));
        assertEquals(3, created.jsonPath().getList("plan.groups").size());

        var allocations = expect(api.get(PLANS + "/" + planId + "/allocations"), 200);
        assertEquals(90, allocations.jsonPath().getList("items").size());
    }

    @Test
    void aStalePlanVersionIsRefusedWithAConflict() {
        Api api = Api.newUser();
        Response created = expect(api.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        List<Map<String, Object>> groups = smallerAllocations(created);

        // The plan is still at version 1, so version 99 is stale.
        Response refused = expect(
            api.post(PLANS + "/" + planId + "/rebalance",
                rebalanceBody(groups, 99, UUID.randomUUID().toString())),
            409);
        assertEquals("Kế hoạch đã thay đổi, hãy tải lại.", refused.jsonPath().getString("detail"));

        // The refused rebalance changed nothing.
        var plan = expect(api.get(PLANS + "/" + planId), 200);
        assertEquals(1, plan.jsonPath().getInt("plan.plan_version"));
    }

    @Test
    void anAcceptedRebalanceBumpsThePlanVersionOnce() {
        Api api = Api.newUser();
        Response created = expect(api.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        List<Map<String, Object>> groups = smallerAllocations(created);

        Response accepted = expect(
            api.post(PLANS + "/" + planId + "/rebalance",
                rebalanceBody(groups, 1, UUID.randomUUID().toString())),
            200);
        assertEquals(2, accepted.jsonPath().getInt("plan_version"));

        var plan = expect(api.get(PLANS + "/" + planId), 200);
        assertEquals(2, plan.jsonPath().getInt("plan.plan_version"));
        assertEquals("REBALANCED", plan.jsonPath().getString("plan.status"));
    }

    @Test
    void aRepeatedIdempotencyKeyDoesNotWriteTwice() {
        Api api = Api.newUser();
        Response created = expect(api.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        List<Map<String, Object>> groups = smallerAllocations(created);
        String key = UUID.randomUUID().toString();

        Response first = expect(
            api.post(PLANS + "/" + planId + "/rebalance", rebalanceBody(groups, 1, key)),
            200);
        Response second = expect(
            api.post(PLANS + "/" + planId + "/rebalance", rebalanceBody(groups, 1, key)),
            200);

        // The second call replayed the stored result instead of writing again.
        assertEquals(first.jsonPath().getInt("plan_version"), second.jsonPath().getInt("plan_version"));
        assertEquals(first.jsonPath().getString("daily_allowance_after"),
            second.jsonPath().getString("daily_allowance_after"));

        var plan = expect(api.get(PLANS + "/" + planId), 200);
        assertEquals(2, plan.jsonPath().getInt("plan.plan_version"));

        var events = expect(api.get(PLANS + "/" + planId + "/events"), 200);
        assertEquals(1, events.jsonPath().getList("items").size());
    }

    @Test
    void aRepeatedIdempotencyKeyReplaysTheFirstResultEvenAfterTheVersionMoved() {
        Api api = Api.newUser();
        Response created = expect(api.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        List<Map<String, Object>> groups = smallerAllocations(created);
        String key = UUID.randomUUID().toString();

        Response first = expect(
            api.post(PLANS + "/" + planId + "/rebalance", rebalanceBody(groups, 1, key)),
            200);

        // A second, different rebalance moves the plan on to version 3.
        expect(api.post(PLANS + "/" + planId + "/rebalance",
            rebalanceBody(groups, 2, UUID.randomUUID().toString())), 200);

        // The first key still replays its own stored result, without a conflict.
        Response replay = expect(
            api.post(PLANS + "/" + planId + "/rebalance", rebalanceBody(groups, 1, key)),
            200);
        assertEquals(first.jsonPath().getInt("plan_version"),
            replay.jsonPath().getInt("plan_version"));

        var plan = expect(api.get(PLANS + "/" + planId), 200);
        assertEquals(3, plan.jsonPath().getInt("plan.plan_version"));
    }

    @Test
    void aMissingIdempotencyKeyIsRefused() {
        Api api = Api.newUser();
        Response created = expect(api.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        Map<String, Object> body = Map.of(
            "expected_version", 1,
            "current_day", 1,
            "purchase_amount", "0",
            "allocations", smallerAllocations(created)
        );

        expect(api.post(PLANS + "/" + planId + "/rebalance", body), 422);

        var plan = expect(api.get(PLANS + "/" + planId), 200);
        assertEquals(1, plan.jsonPath().getInt("plan.plan_version"));
    }

    @Test
    void aPurchaseWithoutAnAccountIsRefused() {
        Api api = Api.newUser();
        Response created = expect(api.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        Map<String, Object> body = Map.of(
            "expected_version", 1,
            "current_day", 1,
            "purchase_amount", "100.00",
            "allocations", smallerAllocations(created),
            "idempotency_key", UUID.randomUUID().toString()
        );

        expect(api.post(PLANS + "/" + planId + "/rebalance", body), 422);

        var plan = expect(api.get(PLANS + "/" + planId), 200);
        assertEquals(1, plan.jsonPath().getInt("plan.plan_version"));
    }

    @Test
    void aRepeatedIdempotencyKeyCreatesThePlanOnlyOnce() {
        Api api = Api.newUser();
        String key = UUID.randomUUID().toString();
        Map<String, Object> body = new java.util.HashMap<>(planInput());
        body.put("idempotency_key", key);

        Response first = expect(api.post(PLANS, body), 201);
        Response second = expect(api.post(PLANS, body), 201);

        assertEquals(first.jsonPath().getLong("plan.id"), second.jsonPath().getLong("plan.id"));

        var plans = expect(api.get(PLANS), 200);
        assertEquals(1, plans.jsonPath().getInt("total"));
    }

    @Test
    void anotherUsersPlanIsNotVisible() {
        Api owner = Api.newUser();
        Response created = expect(owner.post(PLANS, planInput()), 201);
        long planId = created.jsonPath().getLong("plan.id");
        Api stranger = Api.newUser();

        expect(stranger.get(PLANS + "/" + planId), 404);
        // The RPC checks the owner, so a stranger may not rebalance it either.
        expect(stranger.post(PLANS + "/" + planId + "/rebalance",
            rebalanceBody(smallerAllocations(created), 1, UUID.randomUUID().toString())), 403);
    }

    @Test
    void aPlanThatSpendsNothingCannotCoverItsOwnCosts() {
        Api api = Api.newUser();
        // Fixed expenses equal the income, so there is nothing to spend.
        expect(api.post(PLANS, Map.of(
            "total_income", "1000000.00",
            "duration_days", 30,
            "savings_target", "0.00",
            "fixed_expenses", "1000000.00"
        )), 422);
    }

    @Test
    void aPlanStartsOnTheDayTheClientAskedFor() {
        Api api = Api.newUser();
        LocalDate start = LocalDate.now().plusDays(1);
        Response created = expect(api.post(PLANS, Map.of(
            "total_income", "1000000.00",
            "duration_days", 7,
            "savings_target", "0.00",
            "fixed_expenses", "0.00",
            "start_date", start.toString()
        )), 201);
        long planId = created.jsonPath().getLong("plan.id");
        assertEquals(start.toString(), created.jsonPath().getString("plan.start_date"));

        var allocations = expect(api.get(PLANS + "/" + planId + "/allocations"), 200);
        assertEquals(start.toString(),
            allocations.jsonPath().getString("items[0].alloc_date"));
    }
}
