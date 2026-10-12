"""Provider-neutral configuration and safe cloud errors."""

import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[5]


def configured_value(name: str) -> str | None:
    """Read environment first, then ignored local dotenv files without logging."""
    value = os.getenv(name)
    if value is not None:
        return value
    from dotenv import dotenv_values

    for path in (PROJECT_ROOT / "backend/.env", PROJECT_ROOT / ".env"):
        if path.is_file():
            value = dotenv_values(path, encoding="utf-8").get(name)
            if value:
                return value
    return None


class CloudVLMError(RuntimeError):
    """Safe transport failures for caller-controlled retries without fake data."""

    def __init__(
        self,
        message: str,
        *,
        reason: str = "service",
        status_code: int | None = None,
        validation_details: tuple[str, ...] = (),
    ) -> None:
        """Retain error categories without exposing provider payloads or keys."""
        super().__init__(message)
        self.reason = reason
        self.status_code = status_code
        self.validation_details = validation_details
