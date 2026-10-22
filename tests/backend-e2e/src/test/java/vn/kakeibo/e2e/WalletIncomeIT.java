package vn.kakeibo.e2e;

import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import vn.kakeibo.e2e.support.Api;
import static org.junit.jupiter.api.Assertions.*;
import static vn.kakeibo.e2e.support.Api.*;

class WalletIncomeIT {
    private static String requestId() { return UUID.randomUUID().toString().replace("-", ""); }

    @Test
    void deletedOpeningWalletCanBeRecreatedWithSameNameAndRecordedAsIncome() {
        Api api = Api.newUser();
        long oldId = api.account("Ví giống ví cũ", "10000000");
        expect(api.delete(MANAGE + "accounts/" + oldId), 204);
        long newId = api.account("Ví giống ví cũ", "10000000");
        assertNotEquals(oldId, newId);
        expect(api.get(MANAGE + "accounts/" + oldId), 404);
        expect(api.post(MANAGE + "accounts/" + newId + "/initial-income",
            Map.of("client_request_id", requestId(), "expected_balance", "10000000")), 200);
        api.balance(newId, "10000000");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_income", "10000000");
    }

    @Test
    void newWalletIncomeIsAtomicAndRetriesDoNotDuplicateFunds() {
        Api api = Api.newUser();
        var input = Map.of("name", "Ví thu nhập", "account_type", "e_wallet", "balance", "10000000",
            "record_initial_income", true, "client_request_id", requestId());
        long id = expect(api.post(MANAGE + "accounts", input), 201).jsonPath().getLong("id");
        api.balance(id, "10000000");
        money(expect(api.get("/api/v1/overview"), 200), "current_balance", "10000000");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_income", "10000000");
        assertEquals(1, expect(api.get(TRANSACTIONS + "?transaction_type=income"), 200).jsonPath().getInt("total"));
        api.transaction(Map.of("account_id", id, "amount", "100", "transaction_type", "expense"));
        assertEquals(id, expect(api.post(MANAGE + "accounts", input), 201).jsonPath().getLong("id"));
        api.balance(id, "9999900");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_income", "10000000");
        assertEquals(1, expect(api.get(TRANSACTIONS + "?transaction_type=income"), 200).jsonPath().getInt("total"));
        var changed = new java.util.HashMap<String, Object>(input);
        changed.put("balance", "20000000");
        expect(api.post(MANAGE + "accounts", changed), 422);
        api.balance(id, "9999900");
    }

    @Test
    void existingUnusedOpeningBalanceBecomesIncomeWithoutChangingAssets() {
        Api api = Api.newUser();
        long id = api.account("Ví đã tạo", "10000000");
        String path = MANAGE + "accounts/" + id + "/initial-income";
        var input = Map.of("client_request_id", requestId(), "expected_balance", "10000000");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_income", "0");
        expect(api.post(path, input), 200);
        expect(api.post(path, input), 200);
        api.balance(id, "10000000");
        money(expect(api.get("/api/v1/overview"), 200), "current_balance", "10000000");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_income", "10000000");
        money(expect(api.databaseApi().get("/rest/v1/profiles?select=current_balance&id=eq." + api.userId), 200), "[0].current_balance", "10000000");
        assertEquals(1, expect(api.get(TRANSACTIONS), 200).jsonPath().getInt("total"));
        expect(api.post(path, Map.of("client_request_id", requestId(), "expected_balance", "10000000")), 422);
        expect(Api.newUser().post(path, Map.of("client_request_id", requestId(), "expected_balance", "10000000")), 422);
        api.balance(id, "10000000");
    }

    @Test
    void usedWalletCannotHaveItsBalanceReclassifiedAsNewIncome() {
        Api api = Api.newUser();
        long id = api.account("Đã giao dịch", "10000000");
        api.transaction(Map.of("account_id", id, "amount", "100", "transaction_type", "expense"));
        expect(api.post(MANAGE + "accounts/" + id + "/initial-income",
            Map.of("client_request_id", requestId(), "expected_balance", "9999900")), 422);
        api.balance(id, "9999900");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_income", "0");
    }

    @Test
    void ledgerFailureRollsBackTheNewWallet() {
        Api api = Api.newUser();
        int before = expect(api.get(MANAGE + "accounts"), 200).jsonPath().getInt("total");
        // Wallet insert uses zero; the later ledger insert overflows numeric(15,2).
        // Even a direct RPC caller must not leave that new wallet behind.
        var response = api.databaseApi().body(Map.of(
            "p_account", Map.of("name", "Rollback", "account_type", "cash", "balance", "100000000000000"),
            "p_request_id", requestId()
        )).post("/rest/v1/rpc/record_wallet_initial_income");
        assertEquals(400, response.statusCode());
        assertEquals(before, expect(api.get(MANAGE + "accounts"), 200).jsonPath().getInt("total"));
        assertEquals(0, expect(api.get(TRANSACTIONS), 200).jsonPath().getInt("total"));
    }

    @Test
    void changedBalanceMustBeConfirmedAgainBeforeReclassification() {
        Api api = Api.newUser();
        long id = api.account("Số dư thay đổi", "10000000");
        expect(api.patch(MANAGE + "accounts/" + id, Map.of("balance", "20000000")), 200);
        expect(api.post(MANAGE + "accounts/" + id + "/initial-income",
            Map.of("client_request_id", requestId(), "expected_balance", "10000000")), 422);
        api.balance(id, "20000000");
        money(expect(api.get("/api/v1/overview"), 200), "monthly_income", "0");
    }
}
