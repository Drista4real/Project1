"""Tests for ingest_receipt use case."""

from decimal import Decimal
from unittest.mock import AsyncMock, Mock

import pytest

from app.application.use_cases.ingest_receipt import IngestReceipt
from app.domain.interfaces.vlm_interface import (
    IReceiptExtractor,
    ReceiptData,
)


class TestIngestReceipt:
    """Tests for IngestReceipt use case."""

    def setup_method(self):
        self.mock_extractor = Mock(spec=IReceiptExtractor)
        self.use_case = IngestReceipt(extractor=self.mock_extractor)

    def test_init(self):
        """Test initialization."""
        assert self.use_case.extractor == self.mock_extractor

    @pytest.mark.asyncio
    async def test_execute_valid_image(self):
        """Test execute with valid image bytes."""
        expected_data = ReceiptData(
            merchant="Test Merchant",
            total=Decimal("100000"),
            currency="VND",
            items=(),
            issued_on=None,
        )
        self.mock_extractor.extract = AsyncMock(return_value=expected_data)

        result = await self.use_case.execute(b"fake_image_data", "image/jpeg")

        assert result == expected_data
        self.mock_extractor.extract.assert_awaited_once_with(
            b"fake_image_data", "image/jpeg"
        )

    @pytest.mark.asyncio
    async def test_execute_default_mime_type(self):
        """Test execute uses default mime type."""
        expected_data = ReceiptData(
            merchant="Test Merchant",
            total=Decimal("100000"),
            currency="VND",
            items=(),
            issued_on=None,
        )
        self.mock_extractor.extract = AsyncMock(return_value=expected_data)

        result = await self.use_case.execute(b"fake_image_data")

        assert result == expected_data
        self.mock_extractor.extract.assert_awaited_once_with(
            b"fake_image_data", "image/jpeg"
        )

    @pytest.mark.asyncio
    async def test_execute_custom_mime_type(self):
        """Test execute with custom mime type."""
        expected_data = ReceiptData(
            merchant="Test Merchant",
            total=Decimal("100000"),
            currency="VND",
            items=(),
            issued_on=None,
        )
        self.mock_extractor.extract = AsyncMock(return_value=expected_data)

        result = await self.use_case.execute(b"fake_image_data", "image/png")

        assert result == expected_data
        self.mock_extractor.extract.assert_awaited_once_with(
            b"fake_image_data", "image/png"
        )

    @pytest.mark.asyncio
    async def test_execute_empty_bytes_raises(self):
        """Test execute raises ValueError for empty bytes."""
        with pytest.raises(ValueError, match="Receipt image must not be empty"):
            await self.use_case.execute(b"", "image/jpeg")

    @pytest.mark.asyncio
    async def test_execute_none_raises(self):
        """Test execute raises ValueError for None."""
        with pytest.raises(ValueError, match="Receipt image must not be empty"):
            await self.use_case.execute(None, "image/jpeg")  # type: ignore

    @pytest.mark.asyncio
    async def test_execute_propagates_extractor_exception(self):
        """Test execute propagates exceptions from extractor."""
        self.mock_extractor.extract = AsyncMock(
            side_effect=RuntimeError("Extraction failed")
        )

        with pytest.raises(RuntimeError, match="Extraction failed"):
            await self.use_case.execute(b"fake_image_data", "image/jpeg")
