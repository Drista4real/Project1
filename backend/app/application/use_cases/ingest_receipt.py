"""Extract receipt data through a domain port without knowing the VLM vendor."""

from app.domain.interfaces.vlm_interface import IReceiptExtractor, ReceiptData


class IngestReceipt:
    def __init__(self, extractor: IReceiptExtractor) -> None:
        """Depend only on the asynchronous domain receipt port."""
        self.extractor = extractor

    async def execute(self, image: bytes, mime_type: str = "image/jpeg") -> ReceiptData:
        """Validate the input and await extraction without blocking the API loop."""
        if not image:
            raise ValueError("Receipt image must not be empty")
        return await self.extractor.extract(image, mime_type)
