"""Local demo configuration never sends Flutter to a remote service."""

import importlib.util
import json
from pathlib import Path

import pytest


@pytest.fixture
def demo(tmp_path, monkeypatch):
    source = Path(__file__).resolve().parents[2] / "dev/local/demo.py"
    spec = importlib.util.spec_from_file_location("local_demo", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, "RUNTIME", tmp_path)
    monkeypatch.setattr(module, "ENV", tmp_path / "stack.env")
    return module


@pytest.mark.parametrize(
    ("android", "api_url", "auth_url"),
    [
        (False, "http://localhost:18000", "http://localhost:18001"),
        (True, "http://10.0.2.2:18000", "http://10.0.2.2:18001"),
    ],
)
def test_flutter_targets(demo, android, api_url, auth_url):
    assert demo.flutter_config("test-anon-key", android=android) == {
        "API_BASE_URL": api_url,
        "SUPABASE_URL": auth_url,
        "SUPABASE_ANON_KEY": "test-anon-key",
    }


def test_configure_preserves_identity_and_writes_both_targets(demo):
    initial = demo.configure()
    credentials = (demo.RUNTIME / "login.json").read_bytes()
    repeated = demo.configure()

    assert repeated["TEST_DB_PASSWORD"] == initial["TEST_DB_PASSWORD"]
    assert repeated["TEST_JWT_SECRET"] == initial["TEST_JWT_SECRET"]
    assert (demo.RUNTIME / "login.json").read_bytes() == credentials
    web = json.loads((demo.RUNTIME / "flutter-web.json").read_text())
    android = json.loads((demo.RUNTIME / "flutter-android.json").read_text())
    assert web["API_BASE_URL"] == "http://localhost:18000"
    assert web["SUPABASE_URL"] == "http://localhost:18001"
    assert android["API_BASE_URL"] == "http://10.0.2.2:18000"
    assert android["SUPABASE_URL"] == "http://10.0.2.2:18001"
    assert web["SUPABASE_ANON_KEY"] == repeated["TEST_ANON_KEY"]
    assert android["SUPABASE_ANON_KEY"] == repeated["TEST_ANON_KEY"]
