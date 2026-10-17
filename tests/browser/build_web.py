"""Build the real Flutter app with offline browser-smoke configuration."""

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "frontend/build/web"
CONFIG = {
    "scope": "selenium-smoke",
    "SUPABASE_URL": "http://127.0.0.1:1",
    "SUPABASE_ANON_KEY": "sb_publishable_browser_smoke_only",
    "API_BASE_URL": "http://127.0.0.1:1",
    "ENABLE_WEB_SEMANTICS": "true",
}


def main() -> None:
    flutter = shutil.which("flutter")
    if flutter is None:
        raise SystemExit("Install Flutter 3.41.3 and add it to PATH first.")
    # A failed build must not leave a previous bundle marked as ready for tests.
    (WEB / "browser-test-config.json").unlink(missing_ok=True)
    subprocess.run(
        [
            flutter,
            "build",
            "web",
            "--release",
            "--no-pub",
            "--no-web-resources-cdn",
            *[
                f"--dart-define={key}={value}"
                for key, value in CONFIG.items()
                if key != "scope"
            ],
        ],
        cwd=ROOT / "frontend",
        check=True,
    )
    (WEB / "browser-test-config.json").write_text(
        json.dumps(CONFIG, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
