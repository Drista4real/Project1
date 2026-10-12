"""Offline ASR, WAV decoding, fallback, and Vietnamese financial slang tests."""

import io
import unicodedata
import wave
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import numpy as np
import pytest
from app.domain.interfaces.asr_interface import IAudioTranscriber
from app.infrastructure.ai.edge_asr import recognizer as recognizer_module
from app.infrastructure.ai.edge_asr.normalizer import VietnameseFinancialSlangNormalizer
from app.infrastructure.ai.edge_asr.recognizer import SherpaOnnxRecognizer


@pytest.mark.parametrize(
    ("raw", "expected", "amount"),
    [
        ("cơm sườn ba lăm k", "cơm sườn 35000 đồng", 35_000),
        ("cà phê 55 cành", "cà phê 55000 đồng", 55_000),
        ("tiền nhà 3 củ rưỡi", "tiền nhà 3500000 đồng", 3_500_000),
        ("đổ xăng năm chục", "đổ xăng 50000 đồng", 50_000),
        ("mua áo 2 loét", "mua áo 200000 đồng", 200_000),
        ("ăn sáng ba chục", "ăn sáng 30000 đồng", 30_000),
        ("mừng cưới 1 củ rưỡi", "mừng cưới 1500000 đồng", 1_500_000),
        ("đóng trọ 1tr5", "đóng trọ 1500000 đồng", 1_500_000),
        ("nước uống hai cành rưỡi", "nước uống 2500 đồng", 2_500),
        ("mua thuốc 2 lít", "mua thuốc 200000 đồng", 200_000),
        ("vé xe 20 nghìn", "vé xe 20000 đồng", 20_000),
        ("bánh mì 15 ngàn", "bánh mì 15000 đồng", 15_000),
        ("điện 2 triệu", "điện 2000000 đồng", 2_000_000),
        ("mạng 0,5 tr", "mạng 500000 đồng", 500_000),
        ("tiền trọ 3tr5", "tiền trọ 3500000 đồng", 3_500_000),
        ("mua vé 12,5k", "mua vé 12500 đồng", 12_500),
        ("mua sách hai trăm linh năm nghìn", "mua sách 205000 đồng", 205_000),
        ("cà phê ba mươi lăm k", "cà phê 35000 đồng", 35_000),
        ("bún bò bốn mươi mốt nghìn", "bún bò 41000 đồng", 41_000),
        ("mua bánh mười lăm k", "mua bánh 15000 đồng", 15_000),
        ("phí một trăm k", "phí 100000 đồng", 100_000),
        ("giá 50.000 đồng", "giá 50000 đồng", 50_000),
        ("giá 50000đ", "giá 50000 đồng", 50_000),
        ("giá 0k", "giá 0 đồng", 0),
        ("  CÀ PHÊ\n 55 K  ", "cà phê 55000 đồng", 55_000),
    ],
)
def test_money_normalization(raw: str, expected: str, amount: int) -> None:
    """Normalize actual numeric, spoken, abbreviated, and slang transactions."""
    normalizer = VietnameseFinancialSlangNormalizer()
    assert normalizer.normalize(raw) == (expected, amount)
    assert normalizer.normalize(expected) == (expected, amount)


@pytest.mark.parametrize(
    "text",
    [
        "",
        "chưa có giao dịch",
        "mua 2 áo",
        "ngày 12 tháng 5",
        "mua keyboard",
        "phòng 55kabc",
        "tiền -55k",
        "tiền - 55k",
        "khẩu ngữ ba mươi mươi k",
    ],
)
def test_no_money_or_unsupported_grammar(text: str) -> None:
    """Do not invent money from bare numbers, identifiers, or invalid grammar."""
    assert VietnameseFinancialSlangNormalizer().normalize(text) == (text, None)


def test_multiple_amounts_and_unicode() -> None:
    """Keep the first amount, normalize all matches, and accept decomposed Unicode."""
    raw = unicodedata.normalize("NFD", "cà phê 55 cành, bánh mì 20k")
    assert VietnameseFinancialSlangNormalizer().normalize(raw) == (
        "cà phê 55000 đồng, bánh mì 20000 đồng",
        55_000,
    )


def test_normalizer_type_validation() -> None:
    """Reject non-text inputs explicitly."""
    with pytest.raises(TypeError):
        VietnameseFinancialSlangNormalizer().normalize(None)


def wav_bytes(channels: int = 1, sample_width: int = 2) -> bytes:
    """Create a small deterministic PCM WAV without external audio libraries."""
    stream = io.BytesIO()
    with wave.open(stream, "wb") as writer:
        writer.setnchannels(channels)
        writer.setsampwidth(sample_width)
        writer.setframerate(16000)
        writer.writeframes(
            np.asarray([32767, -32768, 1000, -1000] * channels, dtype="<i2").tobytes()
        )
    return stream.getvalue()


def test_missing_models_fallback(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """Absent model files must not import an SDK, download, or crash the app."""
    importer = Mock(side_effect=AssertionError("SDK must not be loaded in mock mode"))
    monkeypatch.setattr(recognizer_module.importlib, "import_module", importer)
    recognizer = SherpaOnnxRecognizer(tmp_path / "absent")
    assert recognizer.is_mock
    assert IAudioTranscriber in SherpaOnnxRecognizer.__mro__
    assert recognizer.transcribe(b"fake_audio") == "cơm sườn ba lăm k"
    assert recognizer.transcribe_and_normalize(b"fake_audio") == (
        "cơm sườn 35000 đồng",
        35_000,
    )
    assert "mock ASR enabled" in caplog.text
    importer.assert_not_called()


def test_placeholder_models_fallback(tmp_path: Path) -> None:
    """Zero-byte placeholders must not be treated as real ONNX artifacts."""
    for name in ("encoder.onnx", "decoder.onnx", "tokens.txt"):
        (tmp_path / name).touch()
    recognizer = SherpaOnnxRecognizer(tmp_path, mock_text="cà phê 55 cành")
    assert recognizer.is_mock
    assert recognizer.transcribe_and_normalize("not-a-real.wav") == (
        "cà phê 55000 đồng",
        55_000,
    )
    with pytest.raises(FileNotFoundError):
        SherpaOnnxRecognizer(tmp_path, allow_mock=False)


@pytest.fixture
def real_branch(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[SherpaOnnxRecognizer, Mock, Mock]:
    """Exercise the real adapter branch with a local SDK double and no ONNX weights."""
    for name in (
        "encoder.onnx",
        "decoder.onnx",
        "encoder.int8.onnx",
        "decoder.int8.onnx",
        "tokens.txt",
    ):
        (tmp_path / name).write_bytes(b"fixture")
    engine = Mock()
    engine.create_stream.side_effect = lambda: SimpleNamespace(
        accept_waveform=Mock(),
        result=SimpleNamespace(text="  cà phê 55 cành  "),
    )
    factory = Mock(return_value=engine)
    sdk = SimpleNamespace(OfflineRecognizer=SimpleNamespace(from_whisper=factory))
    monkeypatch.setattr(
        recognizer_module.importlib, "import_module", Mock(return_value=sdk)
    )
    return SherpaOnnxRecognizer(tmp_path), engine, factory


@pytest.mark.parametrize("channels", [1, 2])
def test_real_wav_and_int8_loading(
    real_branch: tuple[SherpaOnnxRecognizer, Mock, Mock], channels: int
) -> None:
    """Pass normalized mono float32 samples to one stream per decode and use CPU/vi."""
    recognizer, engine, factory = real_branch
    assert not recognizer.is_mock
    options = factory.call_args.kwargs
    assert options["encoder"].endswith("encoder.int8.onnx")
    assert options["decoder"].endswith("decoder.int8.onnx")
    assert (options["language"], options["task"], options["provider"]) == (
        "vi",
        "transcribe",
        "cpu",
    )
    assert recognizer.transcribe(wav_bytes(channels)) == "cà phê 55 cành"
    decoded_stream = engine.decode_stream.call_args.args[0]
    rate, samples = decoded_stream.accept_waveform.call_args.args
    assert rate == 16000
    assert samples.dtype == np.float32
    assert samples.ndim == 1
    assert np.max(np.abs(samples)) <= 1
    assert recognizer.transcribe_and_normalize(wav_bytes()) == (
        "cà phê 55000 đồng",
        55_000,
    )
    assert engine.create_stream.call_count == 2
    factory.assert_called_once()


def test_wav_path_and_raw_buffer(
    real_branch: tuple[SherpaOnnxRecognizer, Mock, Mock], tmp_path: Path
) -> None:
    """Accept files as Path/string and raw mono PCM16 with the supplied sample rate."""
    recognizer, engine, _factory = real_branch
    path = tmp_path / "audio.wav"
    path.write_bytes(wav_bytes())
    assert recognizer.transcribe(path) == recognizer.transcribe(str(path))
    assert (
        recognizer.transcribe(b"\x00\x00\xff\x7f", sample_rate=8000) == "cà phê 55 cành"
    )
    decoded_stream = engine.decode_stream.call_args.args[0]
    assert decoded_stream.accept_waveform.call_args.args[0] == 8000


@pytest.mark.parametrize("audio", [b"", b"\x00", b"RIFFinvalid"])
def test_invalid_audio(
    real_branch: tuple[SherpaOnnxRecognizer, Mock, Mock], audio: bytes
) -> None:
    """Bad audio in real mode must raise rather than return mock financial data."""
    recognizer, _engine, _factory = real_branch
    with pytest.raises(ValueError):
        recognizer.transcribe(audio)


def test_audio_file_missing(
    real_branch: tuple[SherpaOnnxRecognizer, Mock, Mock], tmp_path: Path
) -> None:
    """Explain missing audio paths when genuine recognition is enabled."""
    recognizer, _engine, _factory = real_branch
    with pytest.raises(FileNotFoundError, match="Audio file not found"):
        recognizer.transcribe(tmp_path / "absent.wav")


def test_unsupported_wav(real_branch: tuple[SherpaOnnxRecognizer, Mock, Mock]) -> None:
    """Reject other PCM widths instead of treating their bytes as int16."""
    recognizer, _engine, _factory = real_branch
    with pytest.raises(ValueError, match="16-bit PCM"):
        recognizer.transcribe(wav_bytes(sample_width=1))


def test_decode_failure(real_branch: tuple[SherpaOnnxRecognizer, Mock, Mock]) -> None:
    """A runtime decoding failure cannot be silently converted to a mock result."""
    recognizer, engine, _factory = real_branch
    engine.decode_stream.side_effect = RuntimeError("decode failed")
    with pytest.raises(RuntimeError, match="decoding failed"):
        recognizer.transcribe(wav_bytes())


def test_sdk_missing_with_models(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Model-present configurations explain missing sherpa-onnx dependency."""
    for name in ("encoder.onnx", "decoder.onnx", "tokens.txt"):
        (tmp_path / name).write_bytes(b"fixture")
    monkeypatch.setattr(
        recognizer_module.importlib,
        "import_module",
        Mock(side_effect=ImportError("missing")),
    )
    with pytest.raises(RuntimeError, match="requirements-asr.txt"):
        SherpaOnnxRecognizer(tmp_path)


def test_explicit_mock_with_installed_models(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Demo Mock remains explicit and does not load real models when files exist."""
    for name in ("encoder.int8.onnx", "decoder.int8.onnx", "tokens.txt"):
        (tmp_path / name).write_bytes(b"fixture")
    importer = Mock(side_effect=AssertionError("Explicit mock cannot load the SDK"))
    monkeypatch.setattr(recognizer_module.importlib, "import_module", importer)
    recognizer = SherpaOnnxRecognizer(tmp_path, mock_mode=True)
    assert recognizer.is_mock
    assert recognizer.transcribe_and_normalize(b"fixture") == (
        "cơm sườn 35000 đồng",
        35_000,
    )
    importer.assert_not_called()
