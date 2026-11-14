"""Extract receipt data through a domain port without knowing the VLM vendor."""

from app.domain.interfaces.transaction_parser_interface import TransactionDraft
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

    async def draft(self, image: bytes, mime_type: str) -> TransactionDraft:
        """One printed total is one expense; line items must not duplicate it."""
        receipt = await self.execute(image, mime_type)
        if receipt.currency != "VND":
            raise ValueError("Chỉ hỗ trợ hóa đơn có tổng tiền bằng VND.")
        if (
            not receipt.total.is_finite()
            or receipt.total <= 0
            or receipt.total > 9_999_999_999_999
            or receipt.total != receipt.total.to_integral_value()
        ):
            raise ValueError(
                "Không đọc được tổng tiền VND hợp lệ. Hãy chọn ảnh rõ hơn."
            )
        description = "; ".join(
            [receipt.merchant or "Hóa đơn"]
            + [f"{item.name} ×{item.quantity}" for item in receipt.items]
        )[:2000]
        warnings = [
            "Hãy đối chiếu tổng tiền, ngày và danh mục với hóa đơn trước khi lưu."
        ]
        if not receipt.is_arithmetic_valid:
            warnings.append(
                "Tổng các món chưa khớp tổng hóa đơn; kiểm tra phí và giảm giá."
            )
        if receipt.issued_on is None:
            warnings.append("Không đọc được ngày hóa đơn; đang dùng ngày hôm nay.")
        return TransactionDraft(
            text=description,
            normalized_text=description.lower(),
            amount=int(receipt.total),
            transaction_type="expense",
            category=receipt.category,
            confidence=0.0,  # Arithmetic validity is not a model probability.
            source="QWEN",
            warnings=tuple(warnings),
            occurred_on=receipt.issued_on,
        )
