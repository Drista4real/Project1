package vn.kakeibo.e2e;

import java.util.Map;
import org.junit.jupiter.api.Test;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

class IsolationIT {
    @Test
    void anotherUserCannotReadMutateOrReferenceOwnedTransactionsAndWallets() {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        long wallet = owner.account("Riêng tư", "100");
        long transaction = owner.transaction(Map.of("account_id", wallet, "amount", "5", "transaction_type", "expense"));
        String path = TRANSACTIONS + "/" + transaction;
        expect(other.get(path), 404);
        expect(other.patch(path, Map.of("amount", "50")), 404);
        expect(other.delete(path), 404);
        assertEquals(0, expect(other.get(TRANSACTIONS), 200).jsonPath().getInt("total"));
        expect(other.post(TRANSACTIONS, Map.of("account_id", wallet, "amount", "1", "transaction_type", "expense")), 422);
        expect(other.post(MANAGE + "saving_goals", Map.of("account_id", wallet, "name", "Invalid", "target_amount", "100")), 422);
        long tag = other.create("tags", Map.of("name", "Other"));
        expect(other.post(MANAGE + "transaction_tags", Map.of("transaction_id", transaction, "tag_id", tag)), 422);
        owner.balance(wallet, "95");
    }

    @Test
    void realRlsAndMigrationGuardsAlsoBlockDirectPostgrestAccess() {
        Api owner = Api.newUser();
        Api other = Api.newUser();
        long wallet = owner.account("Owner", "100");
        long transaction = owner.transaction(Map.of("account_id", wallet, "amount", "5", "transaction_type", "expense"));
        String filter = "/rest/v1/transactions?id=eq." + transaction;
        assertTrue(expect(other.databaseApi().get(filter), 200).jsonPath().getList("$").isEmpty());
        assertTrue(expect(other.databaseApi().header("Prefer", "return=representation")
            .body(Map.of("amount", "99")).patch(filter), 200).jsonPath().getList("$").isEmpty());
        assertTrue(expect(other.databaseApi().header("Prefer", "return=representation")
            .delete(filter), 200).jsonPath().getList("$").isEmpty());
        // Own user_id passes the RLS owner policy, but the migration must reject
        // the foreign wallet before its SECURITY DEFINER balance trigger runs.
        var foreignReference = expect(other.databaseApi().body(Map.of("user_id", other.userId,
            "account_id", wallet, "amount", "10", "transaction_type", "expense"))
            .post("/rest/v1/transactions"), 400);
        assertEquals("23514", foreignReference.jsonPath().getString("code"));
        long ownWallet = other.account("Other", "0");
        var forgedOwner = expect(other.databaseApi().body(Map.of("user_id", owner.userId,
            "account_id", wallet, "amount", "10", "transaction_type", "income"))
            .post("/rest/v1/transactions"), 403);
        assertEquals("42501", forgedOwner.jsonPath().getString("code"));
        owner.balance(wallet, "95");
        other.balance(ownWallet, "0");
        money(expect(owner.get(TRANSACTIONS + "/" + transaction), 200), "amount", "5");
    }
}
