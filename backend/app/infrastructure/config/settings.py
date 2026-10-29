from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, HttpUrl, RedisDsn, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

PROJECT_ROOT = Path(__file__).resolve().parents[4]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(PROJECT_ROOT / ".env", PROJECT_ROOT / "backend/.env"),
        env_file_encoding="utf-8",
        extra="ignore",
        env_ignore_empty=True,
    )

    redis_url: RedisDsn = "redis://localhost:6379/0"
    supabase_url: HttpUrl | None = None
    supabase_publishable_key: SecretStr | None = None
    cors_origins: list[str] = ["http://localhost:5173", "http://127.0.0.1:5173"]
    classifier_backend: Literal["lightgbm", "lora"] = "lightgbm"
    classifier_device: Literal["cpu", "cuda"] = "cpu"
    classifier_warmup: bool = True
    classifier_lora_merge: bool = False
    classifier_cpu_threads: int | None = Field(default=None, ge=1, le=64)
    classifier_lora_dir: Path = PROJECT_ROOT / "weights/checkpoints/classifier_lora"
    classifier_lora_cache_dir: Path = PROJECT_ROOT / "weights/cache/phobert-lora"


@lru_cache
def get_settings() -> Settings:
    return Settings()
