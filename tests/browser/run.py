"""Serve a verified local build and run one Selenium browser without shell helpers."""

import argparse
import json
import os
import subprocess
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from build_web import CONFIG, WEB

HERE = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--browser", choices=("chrome", "edge", "firefox"), required=True
    )
    parser.add_argument("--headed", action="store_true")
    args = parser.parse_args()

    marker = WEB / "browser-test-config.json"
    if not marker.is_file() or json.loads(marker.read_text(encoding="utf-8")) != CONFIG:
        raise SystemExit(
            "Build the isolated bundle first: python tests/browser/build_web.py"
        )
    if not (WEB / "index.html").is_file():
        raise SystemExit("Missing Flutter web bundle.")

    artifacts = HERE / "artifacts" / args.browser
    artifacts.mkdir(parents=True, exist_ok=True)
    log = artifacts / "server.log"

    class Handler(SimpleHTTPRequestHandler):
        def handle(self):
            try:
                super().handle()
            except (ConnectionResetError, BrokenPipeError):
                # Browsers close in-flight asset connections on reload/quit.
                pass

        def log_message(self, message, *values):
            with log.open("a", encoding="utf-8") as output:
                output.write((message % values) + "\n")

    with ThreadingHTTPServer(
        ("127.0.0.1", 0), partial(Handler, directory=str(WEB))
    ) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        environment = {
            **os.environ,
            "BROWSER_TEST_BASE_URL": f"http://127.0.0.1:{server.server_port}",
            "BROWSER_TEST_NAME": args.browser,
            "BROWSER_TEST_HEADLESS": "false" if args.headed else "true",
            "BROWSER_TEST_ARTIFACTS": str(artifacts),
            "SE_AVOID_STATS": "true",
            "SE_SKIP_DRIVER_IN_PATH": "true",
        }
        try:
            return subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "pytest",
                    "-c",
                    str(HERE / "pytest.ini"),
                    str(HERE / "scenarios"),
                    f"--junitxml={artifacts / 'junit.xml'}",
                    "-v",
                ],
                cwd=HERE,
                env=environment,
                check=False,
            ).returncode
        finally:
            server.shutdown()
            thread.join(timeout=5)


if __name__ == "__main__":
    raise SystemExit(main())
