"""Streamlit integration tests for genuine local adapters and explicit mocks."""

from pathlib import Path

import pytest
from streamlit.testing.v1 import AppTest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "frontend/app.py"


@pytest.fixture
def demo(monkeypatch: pytest.MonkeyPatch) -> AppTest:
    """Prevent cloud traffic and initialize the actual Streamlit script."""
    monkeypatch.setenv("GEMINI_API_KEY", "")
    monkeypatch.setenv("OPENROUTER_API_KEY", "")
    app = AppTest.from_file(str(APP), default_timeout=60).run()
    assert not app.exception
    return app


def test_empty_inputs_and_mock_receipt(demo: AppTest) -> None:
    """Missing uploads are friendly; mock extraction displays valid receipt metrics."""
    demo.button(key="analyze_text").click().run()
    assert not demo.exception
    assert any("Nhập nội dung" in item.value for item in demo.info)
    demo.button(key="analyze_voice").click().run()
    assert not demo.exception
    assert any("Chọn file âm thanh" in item.value for item in demo.info)
    demo.button(key="analyze_receipt").click().run()
    assert not demo.exception
    assert any("Chọn ảnh" in item.value for item in demo.info)
    demo.button(key="quick_receipt").click().run()
    assert not demo.exception
    assert any("MOCK VLM" in item.value for item in demo.warning)
    assert any(
        "Powered by Qwen2.5-VL (Document VLM)" in item.value for item in demo.markdown
    )
    for key in ("qwen_api_key", "gemini_api_key"):
        widget = demo.text_input(key=key)
        assert widget.proto.type == widget.proto.PASSWORD
    assert any(
        item.label == "Tổng hóa đơn" and item.value == "35.000 ₫"
        for item in demo.metric
    )


def test_local_text_and_voice(demo: AppTest) -> None:
    """Exercise actual cached PhoBERT/LightGBM plus the missing-model ASR mock."""
    demo.text_input(key="transaction_text").set_value("cơm sườn 35k").run()
    demo.button(key="analyze_text").click().run()
    assert not demo.exception and not demo.error
    assert any(
        item.label == "Số tiền" and item.value == "35.000 ₫" for item in demo.metric
    )
    assert any(
        item.label == "Danh mục" and item.value == "Ăn uống" for item in demo.metric
    )
    demo.button(key="quick_voice").click().run()
    assert not demo.exception
    assert any("MOCK ASR" in item.value for item in demo.warning)


def test_standalone_lora_text_without_api(monkeypatch: pytest.MonkeyPatch) -> None:
    """The real LoRA adapter works through Streamlit with no API server."""
    import sys

    import streamlit as st

    sys.path.insert(0, str(ROOT / "backend"))
    from app.infrastructure.config.settings import get_settings

    monkeypatch.setenv("CLASSIFIER_BACKEND", "lora")
    monkeypatch.setenv("CLASSIFIER_DEVICE", "cpu")
    monkeypatch.setenv("HF_HUB_OFFLINE", "1")
    st.cache_resource.clear()
    get_settings.cache_clear()
    try:
        demo = AppTest.from_file(str(APP), default_timeout=60).run()
        demo.text_input(key="transaction_text").set_value("ăn trưa 40k").run()
        demo.button(key="analyze_text").click().run()
        assert not demo.exception and not demo.error
        assert any(
            item.label == "Danh mục" and item.value == "Ăn uống"
            for item in demo.metric
        )
        assert any(
            item.label == "Số tiền" and item.value == "40.000 ₫"
            for item in demo.metric
        )
        assert any("PhoBERT + LoRA" in item.value for item in demo.caption)
    finally:
        st.cache_resource.clear()
        get_settings.cache_clear()


def test_fixed_dashboard_and_custom_payday(demo: AppTest) -> None:
    """Use the actual checkpoint, chart, and persona while changing a salary date."""
    demo.button(key="update_forecast").click().run()
    assert not demo.exception and not demo.error
    assert any(
        item.label == "Còn tới kỳ lương" and item.value == "6 ngày"
        for item in demo.metric
    )
    assert len(demo.get("plotly_chart")) == 1
    assert any(
        "Powered by Gemini 2.5 Flash (Financial Advisor)" in item.value
        for item in demo.markdown
    )
    payday = next(
        item for item in demo.date_input if item.label == "Ngày nhận lương tiếp theo"
    )
    from datetime import timedelta

    payday.set_value(payday.value + timedelta(days=2)).run()
    assert not demo.exception
    assert any("Cập nhật dự báo" in item.value for item in demo.info)
    demo.button(key="update_forecast").click().run()
    assert not demo.exception
    assert any(
        item.label == "Còn tới kỳ lương" and item.value == "8 ngày"
        for item in demo.metric
    )


def test_flexible_zero_burn_and_low_balance(demo: AppTest) -> None:
    """Exercise unbounded runway and an inclusive seven-day depletion warning."""
    demo.radio(key="income_profile").set_value("Thu nhập linh hoạt").run()
    expense = next(
        item for item in demo.number_input if "Chi tiêu trung bình" in item.label
    )
    expense.set_value(0.0).run()
    demo.button(key="update_forecast").click().run()
    assert not demo.exception
    assert any(
        item.label == "Runway" and item.value == "Không giới hạn"
        for item in demo.metric
    )
    expense = next(
        item for item in demo.number_input if "Chi tiêu trung bình" in item.label
    )
    expense.set_value(200_000.0).run()
    balance = next(
        item for item in demo.number_input if item.label == "Số dư hiện tại (VND)"
    )
    balance.set_value(1_000_000.0).run()
    demo.button(key="update_forecast").click().run()
    assert not demo.exception
    assert any("Tốc độ chi tiêu" in item.value for item in demo.warning)
    assert len(demo.get("plotly_chart")) == 1


def test_uploaded_voice_never_uses_mock(monkeypatch: pytest.MonkeyPatch) -> None:
    """Uploaded WAV cannot produce fabricated text when model weights are absent."""
    import io
    import wave
    from types import SimpleNamespace
    from unittest.mock import Mock

    import streamlit as st
    from app.infrastructure.ai.edge_asr import recognizer as asr_module

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as recording:
        recording.setnchannels(1)
        recording.setsampwidth(2)
        recording.setframerate(16000)
        recording.writeframes(b"\x00\x00" * 1600)
    uploaded = SimpleNamespace(
        name="voice.wav", type="audio/wav", getvalue=lambda: buffer.getvalue()
    )
    engine = Mock(is_mock=True)
    st.cache_resource.clear()
    monkeypatch.setenv("GEMINI_API_KEY", "")
    monkeypatch.setenv("OPENROUTER_API_KEY", "")
    monkeypatch.setattr(asr_module, "SherpaOnnxRecognizer", Mock(return_value=engine))

    def uploader(label: str, **kwargs: object) -> object:
        """Provide a WAV only to the voice widget; other uploads stay empty."""
        return uploaded if kwargs.get("key") == "voice_file" else None

    monkeypatch.setattr(st, "file_uploader", uploader)
    demo = AppTest.from_file(str(APP), default_timeout=60).run()
    demo.button(key="analyze_voice").click().run()
    assert not demo.exception
    assert any("Chưa có model ASR" in item.value for item in demo.error)
    assert "voice_result" not in demo.session_state
    engine.transcribe_and_normalize.assert_not_called()
    assert not demo.metric
    st.cache_resource.clear()


def test_uploaded_receipt_never_uses_mock(monkeypatch: pytest.MonkeyPatch) -> None:
    """Uploaded receipt images require real Qwen rather than a fabricated receipt."""
    import io
    from types import SimpleNamespace
    from unittest.mock import Mock

    import streamlit as st
    from google import genai
    from PIL import Image

    buffer = io.BytesIO()
    Image.new("RGB", (10, 10), color="white").save(buffer, format="PNG")
    uploaded = SimpleNamespace(name="receipt.png", getvalue=lambda: buffer.getvalue())
    monkeypatch.setenv("GEMINI_API_KEY", "")
    monkeypatch.setenv("OPENROUTER_API_KEY", "")
    constructor = Mock(
        side_effect=AssertionError("No API key: SDK must not be created")
    )
    monkeypatch.setattr(genai, "Client", constructor)

    def uploader(label: str, **kwargs: object) -> object:
        """Provide an uploaded receipt to the image widget only."""
        return uploaded if kwargs.get("key") == "receipt_file" else None

    monkeypatch.setattr(st, "file_uploader", uploader)
    demo = AppTest.from_file(str(APP), default_timeout=60).run()
    demo.button(key="analyze_receipt").click().run()
    assert not demo.exception
    assert any("Chưa cấu hình Qwen" in item.value for item in demo.error), [
        item.value for item in demo.error
    ]
    assert "receipt_result" not in demo.session_state
    assert not demo.metric
    constructor.assert_not_called()
    demo.button(key="quick_receipt").click().run()
    assert not demo.exception
    assert any("MOCK VLM" in item.value for item in demo.warning)
    constructor.assert_not_called()


def test_receipt_error_shows_field_diagnostics(
    demo: AppTest, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A rejected receipt shows safe field diagnostics without a saved result."""
    from unittest.mock import AsyncMock

    from app.infrastructure.ai.cloud_vlm._common import CloudVLMError
    from app.infrastructure.ai.cloud_vlm.qwen_client import QwenVLMReceiptExtractor

    monkeypatch.setattr(
        QwenVLMReceiptExtractor,
        "extract_receipt",
        AsyncMock(
            side_effect=CloudVLMError(
                "Invalid structured receipt",
                reason="validation",
                validation_details=("items.0.price: cần số nguyên",),
            )
        ),
    )
    demo.button(key="quick_receipt").click().run()
    assert not demo.exception
    assert any("items.0.price" in item.value for item in demo.caption)
    assert "receipt_result" not in demo.session_state
