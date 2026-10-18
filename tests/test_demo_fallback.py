"""Standalone demo fallback tests; no application routes, writes or cloud traffic."""

import asyncio
import io
import sys
import wave
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT))

from app.domain.interfaces.classifier_interface import ClassificationResult  # noqa: E402
from app.infrastructure.ai.cloud_vlm._common import CloudVLMError  # noqa: E402
from frontend import demo_pipeline as pipeline  # noqa: E402


def wav_bytes(seconds: int = 1) -> bytes:
    """Produce a structurally valid test WAV with no actual user speech."""
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(16000)
        audio.writeframes(b"\x01\x00" * 16000 * seconds)
    return buffer.getvalue()


def receipt(**updates: object) -> pipeline.DemoReceipt:
    """Create a receipt whose printed total is independent of model confidence."""
    values = dict(
        merchant_name="Quán cơm",
        transaction_date="2026-10-18",
        items=[dict(name="cơm", quantity=1, price=40000)],
        total_amount=40000,
        category="Ăn uống",
        confidence_score=0.01,
    )
    values.update(updates)
    return pipeline.receipt_arithmetic(pipeline.DemoReceipt(**values))


@pytest.fixture
def cloud(monkeypatch: pytest.MonkeyPatch) -> tuple[AsyncMock, SimpleNamespace]:
    """Use the actual schema transport around an SDK-compatible asynchronous double."""
    generate = AsyncMock(
        return_value=SimpleNamespace(
            parsed={
                "category": "Đi lại",
                "confidence": 0.9,
            }
        )
    )
    client = SimpleNamespace(
        aio=SimpleNamespace(
            models=SimpleNamespace(generate_content=generate),
            aclose=AsyncMock(),
        )
    )
    monkeypatch.setattr(pipeline, "create_demo_client", lambda key: client)
    return generate, client


def local(label: str = "Ăn uống", confidence: float = 0.92) -> Mock:
    """Inject a local classifier without downloading or loading heavyweight models."""
    return Mock(
        return_value=SimpleNamespace(
            classify=Mock(return_value=ClassificationResult(label, confidence))
        )
    )


def test_good_text_does_not_call_gemini(cloud: tuple) -> None:
    """High-confidence valid local predictions bypass the cloud."""
    generate, _ = cloud
    result = asyncio.run(pipeline.DemoPipeline(local()).text("cơm 40k"))
    assert result["source"] == "LOCAL"
    assert result["amount"] == 40000
    generate.assert_not_awaited()


@pytest.mark.parametrize(
    ("label", "confidence"),
    [
        ("Khác", 0.4),
        ("unknown", 0.99),
        ("Ăn uống", float("nan")),
        ("Ăn uống", 1.01),
    ],
)
def test_bad_local_prediction_uses_real_structured_fallback(
    cloud: tuple, label: str, confidence: float
) -> None:
    """Invalid probability/labels must not bypass fallback even at high confidence."""
    generate, client = cloud
    result = asyncio.run(
        pipeline.DemoPipeline(local(label, confidence)).text("vé xe 50k")
    )
    assert result["source"] == "GEMINI"
    assert result["category"] == "Đi lại"
    assert result["amount"] == 50000
    generate.assert_awaited_once()
    client.aio.aclose.assert_awaited_once()


def test_missing_classifier_is_recoverable(cloud: tuple) -> None:
    """Loader errors reach fallback without requiring local weights to exist."""
    loader = Mock(side_effect=FileNotFoundError("missing weights"))
    result = asyncio.run(pipeline.DemoPipeline(loader).text("vé xe 50k"))
    assert result["source"] == "GEMINI"
    assert result["fallback_reason"] == "local_unavailable"


@pytest.mark.parametrize("text", ["cơm", "cơm 40k giảm còn 20k", "cơm -50k"])
def test_uncertain_amounts_stay_unresolved(cloud: tuple, text: str) -> None:
    """Neither category fallback nor the money normalizer invents a confirmed amount."""
    result = asyncio.run(pipeline.DemoPipeline(local()).text(text))
    assert result["amount"] is None
    assert result["warnings"]


def test_sdk_parsed_amount_injection_is_rejected(cloud: tuple) -> None:
    """Local validation forbids classification from changing monetary fields."""
    generate, _ = cloud
    generate.return_value.parsed = {
        "category": "Đi lại",
        "confidence": 0.9,
        "amount": 1,
    }
    result = asyncio.run(pipeline.DemoPipeline(local(confidence=0.2)).text("vé xe 50k"))
    assert result["source"] == "LOCAL"
    assert result["amount"] == 50000
    assert any("validation" in warning for warning in result["warnings"])


@pytest.mark.parametrize("failure", ["missing", "runtime", "empty"])
def test_audio_failure_sends_original_wav_once(cloud: tuple, failure: str) -> None:
    """Recovered transcripts cannot spend a second cloud call on category fallback."""
    generate, client = cloud
    generate.return_value.parsed = {"text": "vé xe 50k"}
    engine = Mock(is_mock=failure == "missing")
    engine.transcribe.return_value = "" if failure == "empty" else "unused"
    if failure == "runtime":
        engine.transcribe.side_effect = RuntimeError("ASR failed")
    original = wav_bytes()
    result = asyncio.run(
        pipeline.DemoPipeline(
            Mock(side_effect=OSError("classifier missing")),
            recognizer=Mock(return_value=engine),
        ).voice(original)
    )
    assert result["extraction_source"] == "GEMINI_AUDIO"
    assert result["category"] is None
    assert result["amount"] == 50000
    assert generate.await_args.kwargs["contents"][1].inline_data.data == original
    generate.assert_awaited_once()
    client.aio.aclose.assert_awaited_once()
    if failure == "missing":
        engine.transcribe.assert_not_called()


@pytest.mark.parametrize(
    ("container", "codec", "mime_type"),
    [("ipod", "aac", "audio/mp4"), ("mp3", "mp3", "audio/mpeg")],
)
def test_compressed_audio_preserves_original_in_fallback(
    cloud: tuple, container: str, codec: str, mime_type: str
) -> None:
    """M4A/MP3 uploads retain their bytes and MIME after merging WAV fallback."""
    av = pytest.importorskip("av")
    output_buffer = io.BytesIO()
    with (
        av.open(io.BytesIO(wav_bytes())) as source,
        av.open(output_buffer, "w", format=container) as target,
    ):
        stream = target.add_stream(codec, rate=16000, layout="mono")
        resampler = av.AudioResampler(format="fltp", layout="mono", rate=16000)
        for frame in [*source.decode(audio=0), None]:
            for converted in resampler.resample(frame):
                for packet in stream.encode(converted):
                    target.mux(packet)
        for packet in stream.encode(None):
            target.mux(packet)
    original = output_buffer.getvalue()
    generate, _ = cloud
    generate.return_value.parsed = {"text": "vé xe 50k"}
    result = asyncio.run(
        pipeline.DemoPipeline(
            local(), recognizer=Mock(side_effect=RuntimeError("ASR unavailable"))
        ).voice(original)
    )
    assert result["extraction_source"] == "GEMINI_AUDIO"
    payload = generate.await_args.kwargs["contents"][1].inline_data
    assert payload.data == original
    assert payload.mime_type == mime_type
    generate.assert_awaited_once()


def test_low_category_confidence_sends_text_not_audio(cloud: tuple) -> None:
    """Usable local transcripts do not cause unnecessary cloud audio re-extraction."""
    generate, _ = cloud
    engine = Mock(is_mock=False)
    engine.transcribe.return_value = "vé xe 50k"
    result = asyncio.run(
        pipeline.DemoPipeline(
            local(confidence=0.2),
            recognizer=Mock(return_value=engine),
        ).voice(wav_bytes())
    )
    assert result["source"] == "GEMINI"
    assert result["extraction_source"] == "LOCAL_ASR"
    assert isinstance(generate.await_args.kwargs["contents"], str)
    generate.assert_awaited_once()


@pytest.fixture
def qwen(monkeypatch: pytest.MonkeyPatch) -> SimpleNamespace:
    """Use a schema-valid, low-confidence receipt by default."""
    primary = SimpleNamespace(
        is_mock=False,
        extract_receipt=AsyncMock(return_value=receipt()),
        aclose=AsyncMock(),
    )
    monkeypatch.setattr(pipeline, "QwenVLMReceiptExtractor", Mock(return_value=primary))
    return primary


def test_valid_receipt_does_not_reextract_for_low_confidence(
    qwen: SimpleNamespace, cloud: tuple
) -> None:
    """Receipt arithmetic signals are independent of model-reported confidence."""
    generate, _ = cloud
    result = asyncio.run(
        pipeline.DemoPipeline(local()).image(b"\xff\xd8\xffimage", "image/jpeg")
    )
    assert result["source"] == "QWEN"
    assert result["amount"] == 40000
    generate.assert_not_awaited()
    qwen.aclose.assert_awaited_once()


@pytest.mark.parametrize(
    "reason", ["timeout", "validation", "truncated", "auth", "network"]
)
def test_qwen_failure_sends_original_image_once(
    qwen: SimpleNamespace, cloud: tuple, reason: str
) -> None:
    """Image fallback validates extraction and uses only local categorization."""
    generate, _ = cloud
    qwen.extract_receipt.side_effect = CloudVLMError("Qwen failure", reason=reason)
    generate.return_value.parsed = receipt().model_dump()
    original = b"\xff\xd8\xffimage"
    result = asyncio.run(pipeline.DemoPipeline(local()).image(original, "image/jpeg"))
    assert result["source"] == "GEMINI_IMAGE"
    assert result["category_source"] == "LOCAL"
    assert result["receipt"]["category"] == "Ăn uống"
    assert result["amount"] == 40000
    assert generate.await_args.kwargs["contents"][1].inline_data.data == original
    generate.assert_awaited_once()
    qwen.aclose.assert_awaited_once()


def test_tax_fee_discount_validation_is_demo_only(
    qwen: SimpleNamespace, cloud: tuple
) -> None:
    """Printed adjustments fix validation without modifying shared receipt contracts."""
    generate, _ = cloud
    qwen.extract_receipt.return_value = receipt(total_amount=100000)
    generate.return_value.parsed = receipt(
        total_amount=43000, tax_amount=4000, fee_amount=1000, discount_amount=2000
    ).model_dump()
    result = asyncio.run(
        pipeline.DemoPipeline(local()).image(b"\xff\xd8\xffimage", "image/jpeg")
    )
    assert result["amount"] == 43000
    assert "tax_amount" not in pipeline.ReceiptExtractionResult.model_fields
    generate.assert_awaited_once()


def test_both_receipt_reads_conflict_preserves_unresolved_amount(
    qwen: SimpleNamespace, cloud: tuple
) -> None:
    """Validation failure never changes line amounts to make the printed total fit."""
    generate, _ = cloud
    qwen.extract_receipt.return_value = receipt(total_amount=100000)
    generate.return_value.parsed = receipt(total_amount=100000).model_dump()
    result = asyncio.run(
        pipeline.DemoPipeline(local()).image(b"\xff\xd8\xffimage", "image/jpeg")
    )
    assert result["amount"] is None
    assert result["receipt"]["total_amount"] == 100000
    assert result["warnings"]
    generate.assert_awaited_once()


@pytest.mark.parametrize("reason", ["timeout", "quota", "auth", "model"])
def test_cloud_errors_never_retry_or_fake_success(cloud: tuple, reason: str) -> None:
    """Provider errors consume the one job budget and leave honest review output."""
    generate, client = cloud
    generate.side_effect = CloudVLMError("Gemini failure", reason=reason)
    job = pipeline.DemoPipeline(local(confidence=0.2))
    result = asyncio.run(job.text("vé xe 50k"))
    assert result["source"] == "LOCAL"
    assert job.budget.used
    generate.assert_awaited_once()
    client.aio.aclose.assert_awaited_once()


def test_budget_and_cancellation_cleanup(cloud: tuple) -> None:
    """Cancelled cloud work closes clients and cannot restore the logical budget."""
    generate, client = cloud
    generate.side_effect = asyncio.CancelledError()
    budget = pipeline.DemoBudget()
    with pytest.raises(asyncio.CancelledError):
        asyncio.run(budget.generate("text", pipeline.Transcript))
    with pytest.raises(CloudVLMError, match="budget"):
        asyncio.run(budget.generate("text", pipeline.Transcript))
    client.aio.aclose.assert_awaited_once()
    generate.assert_awaited_once()


@pytest.mark.parametrize("seconds", [0, 61])
def test_invalid_audio_never_calls_models(cloud: tuple, seconds: int) -> None:
    """Reject malformed/oversized-duration WAV before local or cloud inference."""
    generate, _ = cloud
    loader = Mock()
    data = wav_bytes(seconds) if seconds else b"invalid"
    with pytest.raises(ValueError):
        asyncio.run(pipeline.DemoPipeline(local(), recognizer=loader).voice(data))
    loader.assert_not_called()
    generate.assert_not_awaited()


def test_missing_key_keeps_review_without_constructing_sdk(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Default test mode remains offline even if ignored dotenv files contain keys."""
    from google import genai

    constructor = Mock(side_effect=AssertionError("SDK must stay offline"))
    monkeypatch.setattr(genai, "Client", constructor)
    assert pipeline.create_demo_client("test-secret") is None
    result = asyncio.run(pipeline.DemoPipeline(local(confidence=0.2)).text("vé xe 50k"))
    assert result["warnings"]
    assert result["source"] == "LOCAL"
    constructor.assert_not_called()


def test_demo_client_disables_sdk_retries_without_changing_shared_transport(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Only the demo client receives explicit timeout/retry settings."""
    from google import genai

    monkeypatch.setattr(pipeline, "sys", SimpleNamespace(modules={}))
    monkeypatch.delenv("PYTEST_CURRENT_TEST", raising=False)
    monkeypatch.setenv("APP_ENV", "development")
    constructor = Mock()
    monkeypatch.setattr(genai, "Client", constructor)
    pipeline.create_demo_client("dummy-test-key")
    options = constructor.call_args.kwargs["http_options"]
    assert options.timeout == 20_000
    assert options.retry_options.attempts == 1


def test_invalid_final_receipt_fails_once_without_mock_success(
    qwen: SimpleNamespace,
    cloud: tuple,
) -> None:
    """Fallback output still needs strict dates/types and cannot be blindly accepted."""
    generate, client = cloud
    qwen.is_mock = True
    generate.return_value.parsed = receipt().model_dump()
    generate.return_value.parsed["total_amount"] = "40000"
    with pytest.raises(CloudVLMError) as error:
        asyncio.run(
            pipeline.DemoPipeline(local()).image(b"\xff\xd8\xffimage", "image/jpeg")
        )
    assert error.value.reason == "validation"
    generate.assert_awaited_once()
    client.aio.aclose.assert_awaited_once()
