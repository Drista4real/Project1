"""The benchmark refuses a recording it did not approve."""


import pytest

from scripts.benchmark_inference import read_audio


def test_a_real_recording_is_read(tmp_path):
    recording = tmp_path / "voice.wav"
    recording.write_bytes(b"RIFF0000")

    assert read_audio(recording) == b"RIFF0000"


def test_an_unknown_extension_is_refused(tmp_path):
    recording = tmp_path / "voice.txt"
    recording.write_bytes(b"not audio")

    with pytest.raises(ValueError, match="Unsupported audio format"):
        read_audio(recording)


def test_a_missing_recording_is_refused(tmp_path):
    with pytest.raises(ValueError, match="does not exist"):
        read_audio(tmp_path / "voice.wav")


def test_a_traversing_name_is_refused(tmp_path):
    """A name that walks out of its directory never reaches the read."""
    outside = tmp_path.parent / "outside.wav"
    outside.write_bytes(b"RIFF9999")
    traversal = tmp_path / ".." / outside.name

    with pytest.raises(ValueError, match="does not exist"):
        read_audio(traversal)


def test_a_directory_is_refused(tmp_path):
    folder = tmp_path / "voice.wav"
    folder.mkdir()

    with pytest.raises(ValueError, match="not a regular file"):
        read_audio(folder)


def test_an_oversized_recording_is_refused(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.benchmark_inference.MAX_AUDIO_BYTES", 4)
    recording = tmp_path / "voice.wav"
    recording.write_bytes(b"RIFF0000")

    with pytest.raises(ValueError, match="larger than"):
        read_audio(recording)
