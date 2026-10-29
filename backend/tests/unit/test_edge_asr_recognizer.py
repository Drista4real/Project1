"""Unit tests for edge ASR recognizer module."""

import io
import wave
from pathlib import Path
from unittest.mock import MagicMock, patch

import numpy as np
import pytest

from app.infrastructure.ai.edge_asr.recognizer import (
    SherpaOnnxRecognizer,
    _decode_audio,
    _decode_compressed,
)


class TestDecodeCompressed:
    """Tests for _decode_compressed function."""

    def test_raises_when_pyav_not_installed(self):
        """Test raising RuntimeError when pyav is not available."""
        with patch.dict("sys.modules", {"av": None}):
            with pytest.raises(
                RuntimeError, match="Install backend/requirements-asr.txt"
            ):
                _decode_compressed(b"fake_data")

    def test_raises_on_invalid_audio(self):
        """Test raising ValueError on invalid M4A/MP3 audio."""
        mock_av = MagicMock()
        mock_av.FFmpegError = Exception
        mock_av.open.side_effect = mock_av.FFmpegError("FFmpeg error")
        with patch.dict("sys.modules", {"av": mock_av}):
            with pytest.raises(ValueError, match="Invalid M4A/MP3 audio"):
                _decode_compressed(b"fake_data")

    def test_raises_on_empty_audio(self):
        """Test raising ValueError on empty audio."""
        mock_av = MagicMock()
        mock_container = MagicMock()
        mock_container.decode.return_value = []
        mock_av.open.return_value.__enter__.return_value = mock_container
        with patch.dict("sys.modules", {"av": mock_av}):
            with pytest.raises(ValueError, match="M4A/MP3 audio is empty"):
                _decode_compressed(b"fake_data")


class TestDecodeAudio:
    """Tests for _decode_audio function."""

    def test_rejects_empty_bytes(self):
        """Test rejecting empty bytes."""
        with pytest.raises(ValueError, match="Audio buffer must not be empty"):
            _decode_audio(b"", 16000)

    def test_rejects_nonexistent_file(self):
        """Test raising FileNotFoundError for missing file."""
        with pytest.raises(FileNotFoundError, match="Audio file not found"):
            _decode_audio("/nonexistent/path.wav", 16000)

    def test_rejects_raw_pcm_odd_bytes(self):
        """Test rejecting raw PCM16 with odd byte count."""
        with pytest.raises(
            ValueError, match="Raw PCM16 audio must have an even byte count"
        ):
            _decode_audio(b"123", 16000)

    def test_decodes_raw_pcm16_bytes(self):
        """Test decoding raw PCM16 bytes."""
        samples = np.array([1000, -2000, 3000], dtype="<i2")
        data = samples.tobytes()
        result, rate = _decode_audio(data, 16000)
        assert rate == 16000
        np.testing.assert_array_almost_equal(result, samples.astype(np.float32) / 32768)

    def test_decodes_wav_bytes(self):
        """Test decoding WAV bytes."""
        sample_rate = 16000
        samples = np.array([1000, -2000, 3000], dtype="<i2")
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(samples.tobytes())
        wav_data = buffer.getvalue()

        result, rate = _decode_audio(wav_data, sample_rate)
        assert rate == sample_rate
        np.testing.assert_array_almost_equal(result, samples.astype(np.float32) / 32768)

    def test_decodes_stereo_wav_to_mono(self):
        """Test decoding stereo WAV and converting to mono."""
        sample_rate = 16000
        left = np.array([1000, 2000], dtype="<i2")
        right = np.array([-1000, -2000], dtype="<i2")
        stereo = np.column_stack([left, right]).ravel()
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(stereo.tobytes())
        wav_data = buffer.getvalue()

        result, rate = _decode_audio(wav_data, sample_rate)
        assert rate == sample_rate
        expected = ((left + right) / 2).astype(np.float32) / 32768
        np.testing.assert_array_almost_equal(result, expected)

    def test_rejects_unsupported_wav_format(self):
        """Test rejecting non-16-bit PCM WAV."""
        buffer = io.BytesIO()
        with wave.open(buffer, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(3)  # 24-bit
            wf.setframerate(16000)
            wf.writeframes(b"123")
        wav_data = buffer.getvalue()

        with pytest.raises(
            ValueError, match="Supported WAV format is uncompressed 16-bit PCM"
        ):
            _decode_audio(wav_data, 16000)

    def test_rejects_invalid_wav(self):
        """Test rejecting invalid WAV file."""
        with pytest.raises(ValueError, match="Invalid PCM WAV audio"):
            _decode_audio(b"RIFF....WAVEfmt ", 16000)

    def test_detects_m4a_ftyp(self):
        """Test detecting M4A by ftyp signature."""
        # ftyp at offset 4
        data = b"1234ftypM4A  " + b"\x00" * 100
        with patch(
            "app.infrastructure.ai.edge_asr.recognizer._decode_compressed"
        ) as mock_decode:
            mock_decode.return_value = (np.zeros(16000, dtype=np.float32), 16000)
            result, rate = _decode_audio(data, 16000)
            mock_decode.assert_called_once_with(data)

    def test_detects_mp3_id3(self):
        """Test detecting MP3 by ID3 tag."""
        data = b"ID3" + b"\x00" * 100
        with patch(
            "app.infrastructure.ai.edge_asr.recognizer._decode_compressed"
        ) as mock_decode:
            mock_decode.return_value = (np.zeros(16000, dtype=np.float32), 16000)
            result, rate = _decode_audio(data, 16000)
            mock_decode.assert_called_once_with(data)

    def test_detects_mp3_sync(self):
        """Test detecting MP3 by frame sync."""
        data = b"\xff\xfb" + b"\x00" * 100
        with patch(
            "app.infrastructure.ai.edge_asr.recognizer._decode_compressed"
        ) as mock_decode:
            mock_decode.return_value = (np.zeros(16000, dtype=np.float32), 16000)
            result, rate = _decode_audio(data, 16000)
            mock_decode.assert_called_once_with(data)

    def test_falls_back_to_pcm_on_compressed_decode_failure(self):
        """
        Test falling back to raw PCM when compressed decode fails and not container.
        """
        # MP3 sync but not container, decode fails
        data = b"\xff\xfb" + b"\x00" * 10
        with patch(
            "app.infrastructure.ai.edge_asr.recognizer._decode_compressed",
            side_effect=ValueError("fail"),
        ):
            result, rate = _decode_audio(data, 16000)
            assert rate == 16000


class TestSherpaOnnxRecognizerInit:
    """Tests for SherpaOnnxRecognizer initialization."""

    def test_rejects_invalid_num_threads(self):
        """Test rejecting non-positive num_threads."""
        with pytest.raises(ValueError, match="num_threads must be a positive integer"):
            SherpaOnnxRecognizer(num_threads=0)
        with pytest.raises(ValueError, match="num_threads must be a positive integer"):
            SherpaOnnxRecognizer(num_threads=-1)
        with pytest.raises(ValueError, match="num_threads must be a positive integer"):
            SherpaOnnxRecognizer(num_threads=1.5)  # type: ignore

    def test_rejects_invalid_mock_text(self):
        """Test rejecting empty mock_text."""
        with pytest.raises(ValueError, match="mock_text must be a nonempty string"):
            SherpaOnnxRecognizer(mock_text="")
        with pytest.raises(ValueError, match="mock_text must be a nonempty string"):
            SherpaOnnxRecognizer(mock_text="   ")
        with pytest.raises(ValueError, match="mock_text must be a nonempty string"):
            SherpaOnnxRecognizer(mock_text=123)  # type: ignore

    def test_enables_mock_when_mock_mode_true(self):
        """Test mock mode is enabled when mock_mode=True."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        assert recognizer.is_mock is True

    def test_enables_mock_when_artifacts_missing(self):
        """Test mock mode is enabled when artifacts are missing."""
        with patch(
            "app.infrastructure.ai.edge_asr.recognizer.SherpaOnnxRecognizer._available",
            return_value=False,
        ):
            recognizer = SherpaOnnxRecognizer(allow_mock=True)
            assert recognizer.is_mock is True

    def test_raises_when_artifacts_missing_and_mock_not_allowed(self):
        """
        Test raising FileNotFoundError when artifacts missing and mock not allowed.
        """
        with patch(
            "app.infrastructure.ai.edge_asr.recognizer.SherpaOnnxRecognizer._available",
            return_value=False,
        ):
            with pytest.raises(FileNotFoundError, match="Missing ASR artifacts"):
                SherpaOnnxRecognizer(allow_mock=False)

    def test_enables_mock_when_sherpa_onnx_not_installed(self):
        """Test mock mode when sherpa_onnx not installed."""
        with patch("app.infrastructure.ai.edge_asr.recognizer.MODEL_DIR", Path("/tmp")):
            with patch(
                "app.infrastructure.ai.edge_asr.recognizer.SherpaOnnxRecognizer._available",
                return_value=True,
            ):
                with patch(
                    "importlib.import_module", side_effect=ImportError("No module")
                ):
                    with pytest.raises(
                        RuntimeError, match="Install backend/requirements-asr.txt"
                    ):
                        SherpaOnnxRecognizer(allow_mock=False)

    def test_uses_custom_normalizer(self):
        """Test using custom normalizer."""
        mock_normalizer = MagicMock()
        recognizer = SherpaOnnxRecognizer(normalizer=mock_normalizer, mock_mode=True)
        assert recognizer.normalizer is mock_normalizer


class TestSherpaOnnxRecognizerTranscribe:
    """Tests for transcribe method."""

    def test_rejects_invalid_audio_input_type(self):
        """Test rejecting invalid audio_input type."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        with pytest.raises(
            TypeError, match="audio_input must be bytes, a string path, or Path"
        ):
            recognizer.transcribe(123)  # type: ignore

    def test_rejects_invalid_sample_rate(self):
        """Test rejecting non-positive sample_rate."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        with pytest.raises(ValueError, match="sample_rate must be a positive integer"):
            recognizer.transcribe(b"data", 0)
        with pytest.raises(ValueError, match="sample_rate must be a positive integer"):
            recognizer.transcribe(b"data", -1)
        with pytest.raises(ValueError, match="sample_rate must be a positive integer"):
            recognizer.transcribe(b"data", 16000.5)  # type: ignore

    def test_returns_mock_text_when_mock(self):
        """Test returning mock text in mock mode."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True, mock_text="hello world")
        result = recognizer.transcribe(b"fake_audio")
        assert result == "hello world"

    def test_transcribe_with_real_model(self):
        """Test transcribe with real model (mocked)."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        recognizer.is_mock = False
        mock_recognizer = MagicMock()
        mock_stream = MagicMock()
        mock_stream.result.text = "transcribed text"
        mock_recognizer.create_stream.return_value = mock_stream
        recognizer._recognizer = mock_recognizer

        with patch(
            "app.infrastructure.ai.edge_asr.recognizer._decode_audio"
        ) as mock_decode:
            mock_decode.return_value = (np.zeros(16000, dtype=np.float32), 16000)
            result = recognizer.transcribe(b"fake_audio")
            assert result == "transcribed text"
            mock_recognizer.create_stream.assert_called_once()
            mock_stream.accept_waveform.assert_called_once_with(
                16000, mock_decode.return_value[0]
            )
            mock_recognizer.decode_stream.assert_called_once_with(mock_stream)

    def test_raises_on_decoding_failure(self):
        """Test raising RuntimeError on decoding failure."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        recognizer.is_mock = False
        mock_recognizer = MagicMock()
        mock_recognizer.create_stream.side_effect = RuntimeError("Decode failed")
        recognizer._recognizer = mock_recognizer

        with patch(
            "app.infrastructure.ai.edge_asr.recognizer._decode_audio"
        ) as mock_decode:
            mock_decode.return_value = (np.zeros(16000, dtype=np.float32), 16000)
            with pytest.raises(
                RuntimeError, match="Offline PhoWhisper decoding failed"
            ):
                recognizer.transcribe(b"fake_audio")

    def test_raises_on_non_text_result(self):
        """Test raising RuntimeError when result is not a string."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        recognizer.is_mock = False
        mock_recognizer = MagicMock()
        mock_stream = MagicMock()
        mock_stream.result.text = 123  # Not a string
        mock_recognizer.create_stream.return_value = mock_stream
        recognizer._recognizer = mock_recognizer

        with patch(
            "app.infrastructure.ai.edge_asr.recognizer._decode_audio"
        ) as mock_decode:
            mock_decode.return_value = (np.zeros(16000, dtype=np.float32), 16000)
            with pytest.raises(
                RuntimeError, match="ASR returned a non-text transcription"
            ):
                recognizer.transcribe(b"fake_audio")


class TestSherpaOnnxRecognizerTranscribeAndNormalize:
    """Tests for transcribe_and_normalize method."""

    def test_calls_transcribe_and_normalizer(self):
        """Test calling transcribe and normalizer."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True, mock_text="cơm sườn 35k")
        mock_normalizer = MagicMock()
        mock_normalizer.normalize.return_value = ("cơm sườn 35000", 35000)
        recognizer.normalizer = mock_normalizer

        text, amount = recognizer.transcribe_and_normalize(b"audio", 16000)

        assert text == "cơm sườn 35000"
        assert amount == 35000
        mock_normalizer.normalize.assert_called_once_with("cơm sườn 35k")

    def test_returns_none_amount_when_no_amount(self):
        """Test returning None amount when no amount detected."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True, mock_text="hello world")
        mock_normalizer = MagicMock()
        mock_normalizer.normalize.return_value = ("hello world", None)
        recognizer.normalizer = mock_normalizer

        text, amount = recognizer.transcribe_and_normalize(b"audio", 16000)

        assert text == "hello world"
        assert amount is None


class TestModelFileSelection:
    """Tests for _model_file and _available methods."""

    def test_available_returns_true_for_existing_nonzero_file(self, tmp_path):
        """Test _available returns True for existing non-zero file."""
        file = tmp_path / "test.onnx"
        file.write_bytes(b"data")
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        assert recognizer._available(file) is True

    def test_available_returns_false_for_missing_file(self):
        """Test _available returns False for missing file."""
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        assert recognizer._available(Path("/nonexistent/file.onnx")) is False

    def test_available_returns_false_for_zero_byte_file(self, tmp_path):
        """Test _available returns False for zero-byte file."""
        file = tmp_path / "empty.onnx"
        file.write_bytes(b"")
        recognizer = SherpaOnnxRecognizer(mock_mode=True)
        assert recognizer._available(file) is False

    def test_prefers_int8_over_generic(self, tmp_path):
        """Test preferring INT8 file over generic."""
        int8 = tmp_path / "encoder.int8.onnx"
        generic = tmp_path / "encoder.onnx"
        int8.write_bytes(b"int8")
        generic.write_bytes(b"generic")

        recognizer = SherpaOnnxRecognizer(model_dir=tmp_path, mock_mode=True)
        result = recognizer._model_file("encoder.int8.onnx", "encoder.onnx")
        assert result == int8

    def test_falls_back_to_generic_when_int8_missing(self, tmp_path):
        """Test falling back to generic when INT8 missing."""
        generic = tmp_path / "encoder.onnx"
        generic.write_bytes(b"generic")

        recognizer = SherpaOnnxRecognizer(model_dir=tmp_path, mock_mode=True)
        result = recognizer._model_file("encoder.int8.onnx", "encoder.onnx")
        assert result == generic

    def test_falls_back_to_generic_when_int8_zero_byte(self, tmp_path):
        """Test falling back to generic when INT8 is zero-byte."""
        int8 = tmp_path / "encoder.int8.onnx"
        generic = tmp_path / "encoder.onnx"
        int8.write_bytes(b"")
        generic.write_bytes(b"generic")

        recognizer = SherpaOnnxRecognizer(model_dir=tmp_path, mock_mode=True)
        result = recognizer._model_file("encoder.int8.onnx", "encoder.onnx")
        assert result == generic
