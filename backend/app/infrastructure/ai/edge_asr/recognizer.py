"""Offline PhoWhisper INT8 recognition with an explicit missing-model mock mode."""

import importlib
import io
import logging
import wave
from pathlib import Path
from typing import Any

import numpy as np

from app.domain.interfaces.asr_interface import IAudioTranscriber
from app.infrastructure.ai.edge_asr.normalizer import VietnameseFinancialSlangNormalizer

MODEL_DIR = Path(__file__).resolve().parents[5] / "weights/onnx/phowhisper-tiny"
AudioInput = bytes | str | Path
logger = logging.getLogger(__name__)


def _decode_compressed(data: bytes) -> tuple[np.ndarray, int]:
    """Decode M4A/AAC or MP3 into 16 kHz mono float32 via PyAV's bundled FFmpeg."""
    try:
        import av
    except ImportError as exc:
        raise RuntimeError(
            "Install backend/requirements-asr.txt to decode M4A/MP3 audio"
        ) from exc
    resampler = av.AudioResampler(format="flt", layout="mono", rate=16000)
    chunks: list[np.ndarray] = []
    try:
        with av.open(io.BytesIO(data)) as container:
            # A trailing None flushes samples buffered inside the resampler.
            for frame in [*container.decode(audio=0), None]:
                chunks += [
                    out.to_ndarray().ravel() for out in resampler.resample(frame)
                ]
    except (av.FFmpegError, IndexError) as exc:
        raise ValueError("Invalid M4A/MP3 audio") from exc
    if not chunks:
        raise ValueError("M4A/MP3 audio is empty")
    return np.concatenate(chunks).astype(np.float32), 16000


def _decode_audio(audio_input: AudioInput, sample_rate: int) -> tuple[np.ndarray, int]:
    """Decode WAV/M4A/MP3 paths/bytes or headerless mono PCM16 little-endian bytes."""
    if isinstance(audio_input, bytes):
        data = audio_input
        if not data:
            raise ValueError("Audio buffer must not be empty")
    else:
        path = Path(audio_input)
        try:
            data = path.read_bytes()
        except FileNotFoundError as exc:
            raise FileNotFoundError(f"Audio file not found: {path}") from exc
        except OSError as exc:
            raise RuntimeError(f"Cannot read audio file: {path}") from exc
    # MP4/M4A "ftyp" box, ID3-tagged MP3, or a bare MPEG audio frame sync.
    container = data[4:8] == b"ftyp" or data.startswith(b"ID3")
    mp3_sync = len(data) > 1 and data[0] == 0xFF and data[1] & 0xE0 == 0xE0
    if container or mp3_sync:
        try:
            return _decode_compressed(data)
        except ValueError:
            # Raw PCM whose first sample is in [-4097, -1] also looks like MP3 sync.
            if container or not isinstance(audio_input, bytes):
                raise
    if isinstance(audio_input, bytes) and not data.startswith(b"RIFF"):
        if len(data) % 2:
            raise ValueError("Raw PCM16 audio must have an even byte count")
        return np.frombuffer(data, dtype="<i2").astype(np.float32) / 32768, sample_rate
    source = io.BytesIO(data)
    try:
        with wave.open(source, "rb") as recording:
            if recording.getsampwidth() != 2 or recording.getcomptype() != "NONE":
                raise ValueError("Supported WAV format is uncompressed 16-bit PCM")
            channels = recording.getnchannels()
            if channels not in (1, 2):
                raise ValueError("WAV must be mono or stereo")
            frame_count = recording.getnframes()
            rate = recording.getframerate()
            frames = recording.readframes(frame_count)
            if frame_count == 0 or len(frames) != frame_count * channels * 2:
                raise ValueError("WAV audio is empty or truncated")
    except (wave.Error, EOFError) as exc:
        raise ValueError("Invalid PCM WAV audio") from exc
    samples = (
        np.frombuffer(frames, dtype="<i2").astype(np.float32).reshape(-1, channels)
    )
    return samples.mean(axis=1) / 32768, rate


class SherpaOnnxRecognizer(IAudioTranscriber):
    """Load CPU Whisper exports once; create a separate decoding stream per call."""

    def __init__(
        self,
        model_dir: Path | str = MODEL_DIR,
        *,
        num_threads: int = 1,
        mock_text: str = "cơm sườn ba lăm k",
        allow_mock: bool = True,
        mock_mode: bool = False,
        normalizer: VietnameseFinancialSlangNormalizer | None = None,
    ) -> None:
        """Prefer INT8 filenames; fall back to mock only when artifacts are missing.

        Generic encoder.onnx/decoder.onnx must contain compatible INT8 exports.
        No network requests or model downloads are performed by this adapter.
        """
        if type(num_threads) is not int or num_threads < 1:
            raise ValueError("num_threads must be a positive integer")
        if not isinstance(mock_text, str) or not mock_text.strip():
            raise ValueError("mock_text must be a nonempty string")
        self.model_dir = Path(model_dir)
        self.normalizer = normalizer or VietnameseFinancialSlangNormalizer()
        self.mock_text = mock_text
        self._recognizer: Any = None
        encoder = self._model_file("encoder.int8.onnx", "encoder.onnx")
        decoder = self._model_file("decoder.int8.onnx", "decoder.onnx")
        tokens = self.model_dir / "tokens.txt"
        self.is_mock = mock_mode or not all(
            self._available(p) for p in (encoder, decoder, tokens)
        )
        if self.is_mock:
            message = (
                "Explicit mock ASR enabled"
                if mock_mode
                else f"Missing ASR artifacts in {self.model_dir}; mock ASR enabled"
            )
            if not allow_mock:
                raise FileNotFoundError(message)
            logger.warning(message)
            return
        try:
            sherpa_onnx = importlib.import_module("sherpa_onnx")
        except ImportError as exc:
            raise RuntimeError(
                "Install backend/requirements-asr.txt to load real ASR models"
            ) from exc
        try:
            self._recognizer = sherpa_onnx.OfflineRecognizer.from_whisper(
                encoder=str(encoder),
                decoder=str(decoder),
                tokens=str(tokens),
                language="vi",
                task="transcribe",
                num_threads=num_threads,
                decoding_method="greedy_search",
                provider="cpu",
                debug=False,
            )
        except (RuntimeError, ValueError, OSError) as exc:
            raise RuntimeError(
                f"Cannot initialize offline PhoWhisper in {self.model_dir}"
            ) from exc

    @staticmethod
    def _available(path: Path) -> bool:
        """Treat absent and zero-byte placeholder files as unavailable artifacts."""
        return path.is_file() and path.stat().st_size > 0

    def _model_file(self, int8_name: str, generic_name: str) -> Path:
        """Prefer explicitly named quantized exports over generic ONNX filenames."""
        quantized = self.model_dir / int8_name
        return (
            quantized if self._available(quantized) else self.model_dir / generic_name
        )

    def transcribe(self, audio_input: AudioInput, sample_rate: int = 16000) -> str:
        """Transcribe WAV or PCM16 audio; missing-model mode returns configured text."""
        if not isinstance(audio_input, (bytes, str, Path)):
            raise TypeError("audio_input must be bytes, a string path, or Path")
        if type(sample_rate) is not int or sample_rate <= 0:
            raise ValueError("sample_rate must be a positive integer")
        if self.is_mock:
            return self.mock_text
        samples, rate = _decode_audio(audio_input, sample_rate)
        try:
            stream = self._recognizer.create_stream()
            stream.accept_waveform(rate, samples)
            self._recognizer.decode_stream(stream)
            result = stream.result.text
        except (RuntimeError, ValueError, OSError) as exc:
            raise RuntimeError("Offline PhoWhisper decoding failed") from exc
        if not isinstance(result, str):
            raise RuntimeError("ASR returned a non-text transcription")
        return result.strip()

    def transcribe_and_normalize(
        self, audio_input: AudioInput, sample_rate: int = 16000
    ) -> tuple[str, int | None]:
        """Decode then normalize Vietnamese monetary slang without cloud calls."""
        return self.normalizer.normalize(self.transcribe(audio_input, sample_rate))


PhoWhisperTranscriber = SherpaOnnxRecognizer
