"""Persistent synthetic demo; never reads backend/.env or contacts a remote API."""

import argparse
import base64
import hashlib
import hmac
import json
import secrets
import subprocess
import time
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
RUNTIME = HERE / "runtime"
ENV = RUNTIME / "stack.env"
API = "http://127.0.0.1:18000/api/v1"
AUTH = "http://127.0.0.1:18001/auth/v1"
PROJECT = "project1-local-demo"


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def flutter_config(anon_key, *, android=False):
    """Use loopback services; the Android emulator maps its host to 10.0.2.2."""
    config = {
        "API_BASE_URL": "http://localhost:18000",
        "SUPABASE_URL": "http://localhost:18001",
        "SUPABASE_ANON_KEY": anon_key,
    }
    if android:
        # This fixed emulator alias reaches the same loopback-only Docker ports.
        for key in ("API_BASE_URL", "SUPABASE_URL"):
            config[key] = config[key].replace("localhost", "10.0.2.2")
    return config


def configure():
    RUNTIME.mkdir(exist_ok=True)
    if ENV.exists():
        values = dict(
            line.split("=", 1) for line in ENV.read_text().splitlines() if "=" in line
        )
        if values.get("LOCAL_DEMO") != PROJECT:
            raise RuntimeError(
                "Refusing to reuse configuration for another environment."
            )
    else:
        values = {
            "LOCAL_DEMO": PROJECT,
            "TEST_DB_PASSWORD": secrets.token_hex(24),
            "TEST_JWT_SECRET": secrets.token_hex(32),
            "E2E_LOCAL": "true",
        }

    def encode(value):
        return (
            base64.urlsafe_b64encode(json.dumps(value).encode()).rstrip(b"=").decode()
        )

    now = int(time.time())
    message = (
        encode({"alg": "HS256", "typ": "JWT"})
        + "."
        + encode(
            {
                "role": "anon",
                "iss": "supabase",
                "iat": now,
                "exp": now + 365 * 86400,
            }
        )
    )
    signature = hmac.new(
        values["TEST_JWT_SECRET"].encode(), message.encode(), hashlib.sha256
    ).digest()
    values["TEST_ANON_KEY"] = (
        message + "." + base64.urlsafe_b64encode(signature).rstrip(b"=").decode()
    )
    ENV.write_text(
        "".join(f"{key}={value}\n" for key, value in values.items()), encoding="utf-8"
    )
    if not (RUNTIME / "login.json").exists():
        write_json(
            RUNTIME / "login.json",
            {
                "email": "demo-local@example.com",
                "password": "Local!" + secrets.token_hex(12),
            },
        )
    for target in ("web", "android"):
        write_json(
            RUNTIME / f"flutter-{target}.json",
            flutter_config(values["TEST_ANON_KEY"], android=target == "android"),
        )
    return values


def compose(*args):
    subprocess.run(
        [
            "docker",
            "compose",
            "--project-name",
            PROJECT,
            "--env-file",
            str(ENV),
            "-f",
            str(ROOT / "tests/backend-e2e/compose.yaml"),
            "-f",
            str(HERE / "compose.yaml"),
            *args,
        ],
        cwd=ROOT,
        check=True,
    )


class LocalApi:
    def __init__(self, key):
        self.key = key
        self.token = None
        self.user_id = None

    def request(self, method, path, body=None, *, auth=False):
        base = AUTH if auth else API
        headers = {"Content-Type": "application/json", "apikey": self.key}
        if self.token and not auth:
            headers["Authorization"] = "Bearer " + self.token
        request = Request(
            base + path,
            data=None if body is None else json.dumps(body).encode(),
            headers=headers,
            method=method,
        )
        with urlopen(request, timeout=30) as response:
            data = response.read()
            return json.loads(data) if data else None

    def login(self):
        credentials = json.loads((RUNTIME / "login.json").read_text())
        try:
            session = self.request(
                "POST", "/token?grant_type=password", credentials, auth=True
            )
        except HTTPError as error:
            if error.code != 400:
                raise
            self.request("POST", "/signup", credentials, auth=True)
            session = self.request(
                "POST", "/token?grant_type=password", credentials, auth=True
            )
        self.token = session["access_token"]
        self.user_id = session["user"]["id"]

    def records(self, resource):
        path = "/transactions" if resource == "transactions" else "/manage/" + resource
        rows = []
        while True:
            page = self.request("GET", f"{path}?limit=100&offset={len(rows)}")
            rows.extend(page["items"])
            if len(rows) >= page["total"] or not page["items"]:
                return rows

    def ensure(self, resource, values, fields=("name",)):
        for row in self.records(resource):
            if all(row.get(field) == values.get(field) for field in fields):
                return row
        path = "/transactions" if resource == "transactions" else "/manage/" + resource
        return self.request("POST", path, values)


def seed(api):
    state_path = RUNTIME / "seed.json"
    if (
        state_path.exists()
        and json.loads(state_path.read_text()).get("user_id") == api.user_id
    ):
        print("Demo already seeded; preserving your edits.")
        return
    wallets = {}
    for name, kind, amount, income in [
        ("Tiền mặt", "cash", "2000000", False),
        ("Ngân hàng", "bank", "30000000", True),
        ("Ví điện tử", "e_wallet", "10000000", True),
    ]:
        values = {
            "name": "[Demo] " + name,
            "account_type": kind,
            "balance": amount,
            "record_initial_income": income,
        }
        if income:
            values["client_request_id"] = hashlib.sha256(name.encode()).hexdigest()[:32]
        wallets[name] = api.ensure("accounts", values)["id"]
    categories = {}
    for name, pillar in [
        ("Ăn uống", "needs"),
        ("Di chuyển", "needs"),
        ("Du lịch", "wants"),
        ("Sách", "culture"),
        ("Sức khỏe", "unexpected"),
    ]:
        categories[name] = api.ensure(
            "categories",
            {
                "name": "[Demo] " + name,
                "pillar": pillar,
                "is_income": False,
            },
        )["id"]
    tags = {
        name: api.ensure("tags", {"name": name})["id"]
        for name in ["Du lịch", "Gia đình", "Công việc", "Học tập", "Bạn bè"]
    }
    now = datetime.now(timezone(timedelta(hours=7)))
    plans = [
        (2, "Ăn trưa", "70000", "Tiền mặt", "Ăn uống", ["Công việc"]),
        (4, "Đi chợ", "420000", "Ví điện tử", "Ăn uống", ["Gia đình"]),
        (7, "Cà phê", "65000", "Tiền mặt", "Ăn uống", ["Công việc", "Bạn bè"]),
        (10, "Mua sách", "180000", "Ngân hàng", "Sách", ["Học tập"]),
        (13, "Khách sạn", "1200000", "Ngân hàng", "Du lịch", ["Du lịch"]),
        (15, "Vé máy bay", "800000", "Ngân hàng", "Du lịch", ["Du lịch", "Gia đình"]),
        (18, "Taxi", "90000", "Ví điện tử", "Di chuyển", ["Công việc"]),
        (20, "Quà gia đình", "250000", "Tiền mặt", "Ăn uống", ["Gia đình"]),
        (
            22,
            "Thuốc dự phòng du lịch (chưa gắn thẻ)",
            "130000",
            "Ví điện tử",
            "Sức khỏe",
            [],
        ),
    ]
    for day, name, amount, wallet, category, labels in plans:
        record = api.ensure(
            "transactions",
            {
                "clean_description": "[Demo] " + name,
                "raw_description": "[Demo] " + name,
                "amount": amount,
                "transaction_type": "expense",
                "account_id": wallets[wallet],
                "category_id": categories[category],
                "transaction_date": now.replace(
                    day=min(day, now.day), hour=12
                ).isoformat(),
            },
            ("clean_description",),
        )
        for label in labels:
            api.ensure(
                "transaction_tags",
                {"transaction_id": record["id"], "tag_id": tags[label]},
                ("transaction_id", "tag_id"),
            )
    transfer = api.ensure(
        "transactions",
        {
            "clean_description": "[Demo] Rút tiền cho chuyến đi",
            "amount": "500000",
            "transaction_type": "transfer",
            "account_id": wallets["Ngân hàng"],
            "to_account_id": wallets["Tiền mặt"],
            "transaction_date": now.isoformat(),
        },
        ("clean_description",),
    )
    api.ensure(
        "transaction_tags",
        {"transaction_id": transfer["id"], "tag_id": tags["Du lịch"]},
        ("transaction_id", "tag_id"),
    )
    month = now.strftime("%Y-%m-01")
    budgets = [
        (None, None, "15000000"),
        (None, "needs", "8000000"),
        (None, "wants", "3000000"),
        (None, "culture", "2000000"),
        (None, "unexpected", "2000000"),
    ]
    budgets += [
        (categories[n], None, amount)
        for n, amount in [
            ("Ăn uống", "3000000"),
            ("Di chuyển", "2000000"),
            ("Du lịch", "2000000"),
            ("Sách", "1000000"),
            ("Sức khỏe", "1000000"),
        ]
    ]
    for category, pillar, amount in budgets:
        api.ensure(
            "budgets",
            {
                "category_id": category,
                "pillar": pillar,
                "month_year": month,
                "limit_amount": amount,
            },
            ("category_id", "pillar", "month_year"),
        )
    overview = api.request("GET", "/overview")
    expected = {
        "current_balance": "38795000",
        "monthly_income": "40000000",
        "monthly_expense": "3205000",
    }
    if any(Decimal(overview[k]) != Decimal(v) for k, v in expected.items()):
        raise RuntimeError(
            "Demo ledger totals do not reconcile; seed state was not marked complete."
        )
    write_json(
        state_path,
        {"user_id": api.user_id, "month": month, "expected_overview": expected},
    )


def verify(api):
    overview = api.request("GET", "/overview")
    transactions, tags, links = (
        api.records(r) for r in ["transactions", "tags", "transaction_tags"]
    )
    travel = next((t["id"] for t in tags if t["name"] == "Du lịch"), None)
    attached = {link["transaction_id"] for link in links if link["tag_id"] == travel}
    print(
        json.dumps(
            {
                "overview": overview,
                "transactions": len(transactions),
                "tags": len(tags),
                "tag_links": len(links),
                "travel_tag_matches": len(attached),
            },
            ensure_ascii=False,
        )
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["start", "stop", "reset", "seed", "verify"])
    command = parser.parse_args().command
    if command in {"stop", "reset"}:
        if not ENV.exists():
            raise RuntimeError("No local demo configuration. Nothing to stop/reset.")
        compose(
            "down", "--remove-orphans", *(["--volumes"] if command == "reset" else [])
        )
        if command == "reset":
            (RUNTIME / "seed.json").unlink(missing_ok=True)
        return
    values = configure()
    if command == "start":
        compose("config", "--quiet")
        compose("up", "--detach", "--build", "--wait", "--wait-timeout", "240", "api")
    api = LocalApi(values["TEST_ANON_KEY"])
    api.login()
    if command in {"start", "seed"}:
        seed(api)
    verify(api)
    print("Local API: http://localhost:18000 | Auth: http://localhost:18001")
    print("Demo login: dev/local/runtime/login.json | Run app: dev/local/run-app.ps1")


if __name__ == "__main__":
    try:
        main()
    except HTTPError as error:
        raise SystemExit(
            f"Local request failed: HTTP {error.code}. "
            "No authentication response was logged."
        ) from None
