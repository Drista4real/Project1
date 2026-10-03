from functools import lru_cache

from pydantic import HttpUrl, RedisDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        env_ignore_empty=True,
    )

    redis_url: RedisDsn = "redis://localhost:6379/0"
    supabase_url: HttpUrl | None = None
    supabase_publishable_key: SecretStr | None = None
    cors_origins: list[str] = ["http://localhost:5173", "http://127.0.0.1:5173"]


@lru_cache
def get_settings() -> Settings:
    return Settings()
