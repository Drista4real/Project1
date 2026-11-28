"""Audio and typed input use the same parser domain port."""

from unittest.mock import AsyncMock, Mock

import pytest

from app.application.use_cases.parse_transaction import ParseTransaction


@pytest.mark.asyncio
async def test_audio_uses_shared_parser_once() -> None:
    """ASR runs off the event loop; its transcript follows normal batch parsing."""
    parser = Mock(parse_many=AsyncMock(return_value=("draft",)))
    transcriber = Mock(transcribe=Mock(return_value="cơm 35k"))
    result = await ParseTransaction(parser).execute_audio(b"pcm", transcriber)
    assert result == ("draft",)
    transcriber.transcribe.assert_called_once_with(b"pcm", 16000)
    parser.parse_many.assert_awaited_once_with("cơm 35k")


@pytest.mark.asyncio
async def test_empty_transcript_never_reaches_classifier() -> None:
    """A failed transcription cannot produce a fabricated transaction."""
    parser = Mock()
    with pytest.raises(ValueError, match="1 to 2000"):
        await ParseTransaction(parser).execute_audio(
            b"pcm", Mock(transcribe=Mock(return_value=" "))
        )
    parser.parse_many.assert_not_called()
