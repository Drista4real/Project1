"""Receipt adapter exports: all document extraction is handled by Qwen."""

from app.infrastructure.ai.cloud_vlm.qwen_client import (
    QwenVLMReceiptExtractor,
    check_receipt_arithmetic,
)

DocumentVLMClient = QwenVLMReceiptExtractor

__all__ = ["DocumentVLMClient", "QwenVLMReceiptExtractor", "check_receipt_arithmetic"]
