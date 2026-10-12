"""Domain contract for transcribing financial audio without SDK dependencies."""

from typing import Protocol


class IAudioTranscriber(Protocol):
    def transcribe(self, audio_input: bytes, sample_rate: int = 16000) -> str:
        """Return text from mono audio encoded in the adapter's supported format."""
        ...
