"""Shared asynchronous Gemini transport, bounded requests, and local validation."""

import asyncio
import math
import os
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Any, TypeVar

from pydantic import BaseModel, SecretStr, ValidationError

from app.infrastructure.ai.cloud_vlm._common import CloudVLMError

if TYPE_CHECKING:
    from google import genai

Schema = TypeVar("Schema", bound=BaseModel)
PROJECT_ROOT = Path(__file__).resolve().parents[5]


def _configured_value(name: str) -> str | None:
    """Read environment first, then ignored local dotenv files without mutating it."""
    environment_key = os.getenv(name)
    if environment_key is not None:
        return environment_key
    from dotenv import dotenv_values

    for path in (PROJECT_ROOT / "backend/.env", PROJECT_ROOT / ".env"):
        if path.is_file():
            value = dotenv_values(path, encoding="utf-8").get(name)
            if value:
                return value
    return None


def configured_api_key() -> str | None:
    """Read the key without logging or exposing its value."""
    return _configured_value("GEMINI_API_KEY")


def configured_model_name() -> str:
    """Allow the demo to select a supported Gemini version through local config."""
    return _configured_value("GEMINI_MODEL") or "gemini-2.5-flash"


def configured_input_model_name() -> str:
    """Use a separately configurable fast model for transaction classification."""
    return _configured_value("GEMINI_INPUT_MODEL") or "gemini-3.1-flash-lite"


def create_client(
    api_key: str | SecretStr | None,
    test_mode: bool | None,
    timeout_seconds: float,
) -> "genai.Client | None":
    """Read explicit config or GEMINI_API_KEY; default tests never access the cloud."""
    if not math.isfinite(timeout_seconds) or timeout_seconds <= 0:
        raise ValueError("timeout_seconds must be finite and positive")
    testing = (
        test_mode
        if test_mode is not None
        else (
            "pytest" in sys.modules
            or bool(os.getenv("PYTEST_CURRENT_TEST"))
            or os.getenv("APP_ENV", "").lower() in {"test", "testing"}
        )
    )
    if testing:
        return None
    key = api_key if api_key is not None else configured_api_key()
    if isinstance(key, SecretStr):
        key = key.get_secret_value()
    if testing or not key or not key.strip():
        return None
    try:
        from google import genai
        from google.genai import types
    except ImportError as exc:
        raise RuntimeError(
            "Install backend/requirements-cloud-vlm.txt for Gemini"
        ) from exc

    return genai.Client(
        api_key=key.strip(),
        http_options=types.HttpOptions(timeout=max(1, int(timeout_seconds * 1000))),
    )


async def generate_structured(  # noqa: UP047 -- Python 3.10+ per RULES.md
    client: "genai.Client",
    model_name: str,
    contents: Any,
    schema: type[Schema],
    timeout_seconds: float,
    *,
    fast: bool = False,
) -> Schema:
    """Await Gemini JSON-schema output, then independently validate its payload."""
    from google.genai import errors, types
    from httpx import HTTPError

    try:
        response = await asyncio.wait_for(
            client.aio.models.generate_content(
                model=model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_json_schema=schema.model_json_schema(),
                    temperature=0,
                    thinking_config=(
                        types.ThinkingConfig(thinking_level="low")
                        if fast and model_name.startswith("gemini-3")
                        else None
                    ),
                    max_output_tokens=512 if fast else None,
                ),
            ),
            timeout=timeout_seconds,
        )
    except TimeoutError as exc:
        raise CloudVLMError(
            "Gemini request failed or timed out", reason="timeout"
        ) from exc
    except errors.APIError as exc:
        reason = {
            400: "request",
            401: "auth",
            403: "auth",
            404: "model",
            429: "quota",
            500: "unavailable",
            502: "unavailable",
            503: "unavailable",
            504: "timeout",
        }.get(exc.code, "service")
        raise CloudVLMError(
            "Gemini request failed or timed out", reason=reason, status_code=exc.code
        ) from exc
    except (HTTPError, OSError) as exc:
        raise CloudVLMError(
            "Gemini request failed or timed out", reason="network"
        ) from exc
    try:
        parsed = response.parsed
        if isinstance(parsed, BaseModel):
            return schema.model_validate(parsed.model_dump())
        if isinstance(parsed, dict):
            return schema.model_validate(parsed)
        if not response.text:
            raise ValueError("Gemini returned no structured output")
        return schema.model_validate_json(response.text)
    except (ValidationError, ValueError, TypeError) as exc:
        raise CloudVLMError(
            "Gemini returned an invalid structured response", reason="validation"
        ) from exc
