"""Generate disposable credentials on the Actions runner, with no repo secrets."""

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


if os.environ.get("GITHUB_ACTIONS") != "true":
    raise SystemExit("Run the Backend Java E2E workflow on GitHub Actions.")

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
for value in values.values():
    print(f"::add-mask::{value}")
destination = Path(__file__).resolve().parents[1] / ".env.ci"
destination.write_text("".join(f"{key}={value}\n" for key, value in values.items()))
destination.chmod(0o600)
