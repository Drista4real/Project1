from decimal import Decimal

import httpx
import pytest
from supabase import ClientOptions, create_client

from app.infrastructure.repositories.account_totals import included_account_total


@pytest.mark.parametrize("count", [0, 2, 500, 501])
def test_wallet_total_filters_owner_and_inclusion_and_reads_every_page(count):
    wallets = [
        {"owner": "owner", "included": True, "balance": "0.10"} for _ in range(count)
    ] + [
        {"owner": "owner", "included": False, "balance": "9000.00"},
        {"owner": "other", "included": True, "balance": "8000.00"},
    ]
    offsets = []

    def handle(request):
        params = request.url.params
        assert params["user_id"] == "eq.owner"
        assert params["is_included_in_total"] == "eq.true"
        assert "is_archived" not in params
        offset = int(params["offset"])
        offsets.append(offset)
        rows = [w for w in wallets if w["owner"] == "owner" and w["included"]]
        return httpx.Response(200, json=rows[offset : offset + int(params["limit"])])

    with httpx.Client(transport=httpx.MockTransport(handle)) as transport:
        client = create_client(
            "https://example.supabase.co",
            "sb_publishable_example",
            options=ClientOptions(httpx_client=transport),
        )
        assert (
            Decimal(included_account_total(client, "owner")) == Decimal("0.10") * count
        )
    assert offsets == ([0, 500] if count >= 500 else [0])
