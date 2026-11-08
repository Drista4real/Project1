"""Prepare natural-language transaction input for user confirmation."""

import asyncio

from app.domain.interfaces.asr_interface import IAudioTranscriber
from app.domain.interfaces.transaction_parser_interface import (
    ITransactionParser,
    TransactionDraft,
)


class ParseTransaction:
    """Use only the parser domain port; persistence is a separate user action."""

    def __init__(self, parser: ITransactionParser) -> None:
        """Receive the configured parser adapter."""
        self.parser = parser

    async def execute(self, text: str) -> TransactionDraft:
        """Reject empty input before passing it to the parser."""
        text = text.strip()
        if not text or len(text) > 2000:
            raise ValueError("Transaction text must contain 1 to 2000 characters")
        return await self.parser.parse(text)

    async def execute_many(self, text: str) -> tuple[TransactionDraft, ...]:
        """Validate the request and delegate language boundaries to the adapter."""
        text = text.strip()
        if not text or len(text) > 2000:
            raise ValueError("Transaction text must contain 1 to 2000 characters")
        return await self.parser.parse_many(text)

    async def execute_audio(
        self,
        audio: bytes,
        transcriber: IAudioTranscriber,
        sample_rate: int = 16000,
    ) -> tuple[TransactionDraft, ...]:
        """Route spoken text through the same draft parser as typed input."""
        if not audio:
            raise ValueError("Audio must not be empty")
        text = await asyncio.to_thread(transcriber.transcribe, audio, sample_rate)
        return await self.execute_many(text)
