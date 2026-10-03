import pytest
from pydantic import ValidationError

from app.infrastructure.config.settings import Settings


def test_settings_reads_redis_url_from_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6380/2")

    settings = Settings(_env_file=None)

    assert settings.redis_url.host == "localhost"
    assert settings.redis_url.port == 6380
    assert settings.redis_url.path == "/2"


def test_supabase_credentials_are_optional_for_foundation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379/0")
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_PUBLISHABLE_KEY", raising=False)

    settings = Settings(_env_file=None)

    assert settings.supabase_url is None
    assert settings.supabase_publishable_key is None


def test_settings_default_to_local_redis(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("REDIS_URL", raising=False)

    settings = Settings(_env_file=None)

    assert settings.redis_url.host == "localhost"
    assert settings.redis_url.port == 6379


def test_settings_reject_invalid_redis_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("REDIS_URL", "not-a-redis-url")

    with pytest.raises(ValidationError):
        Settings(_env_file=None)
