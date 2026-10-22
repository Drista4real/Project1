"""Generate disposable credentials for Actions or explicitly enabled local Docker."""

import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import time


def encode(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


is_actions = os.environ.get("GITHUB_ACTIONS") == "true"
is_local = os.environ.get("E2E_LOCAL") == "true"
if not (is_actions or is_local):
    raise SystemExit(
        "Use GitHub Actions or explicitly set E2E_LOCAL=true for disposable Docker tests."
    )

jwt_secret = secrets.token_hex(32)
issued_at = int(time.time())
header = encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
claims = encode(json.dumps({
    "role": "anon", "iss": "supabase", "iat": issued_at, "exp": issued_at + 7200,
}).encode())
message = f"{header}.{claims}"
signature = encode(hmac.new(jwt_secret.encode(), message.encode(), hashlib.sha256).digest())
values = {
    "TEST_DB_PASSWORD": secrets.token_hex(24),
    "TEST_JWT_SECRET": jwt_secret,
    "TEST_ANON_KEY": f"{message}.{signature}",
}
if is_actions:
    for value in values.values():
        print(f"::add-mask::{value}")
values["E2E_LOCAL"] = "true" if is_local else "false"
values["GITHUB_ACTIONS"] = "true" if is_actions else "false"
destination = Path(__file__).resolve().parents[1] / ".env.ci"
destination.write_text("".join(f"{key}={value}\n" for key, value in values.items()))
destination.chmod(0o600)
