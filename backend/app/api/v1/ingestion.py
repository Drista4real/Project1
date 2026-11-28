"""Authenticated text and bounded receipt ingestion; drafts never write a ledger."""

import io
import warnings
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request
from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, Field
from starlette.concurrency import run_in_threadpool

from app.api.dependencies import UserDependency
from app.application.use_cases.ingest_receipt import IngestReceipt
from app.application.use_cases.parse_transaction import ParseTransaction
from app.domain.interfaces.transaction_parser_interface import TransactionDraft
from app.domain.interfaces.vlm_interface import ReceiptData
from app.infrastructure.ai.cloud_vlm._common import CloudVLMError
from app.infrastructure.ai.transaction_parser import NaturalTransactionParser

router = APIRouter(prefix="/api/v1/ingestion", tags=["AI ingestion"])
MAX_RECEIPT_BYTES = 8 * 1024 * 1024
MAX_RECEIPT_PIXELS = 20_000_000
RECEIPT_FORMATS = {"image/jpeg": "JPEG", "image/png": "PNG", "image/webp": "WEBP"}


class InputCategory(BaseModel):
    """Reference labels; saving still validates ownership separately."""

    name: str = Field(min_length=1, max_length=100)
    is_income: bool = False


class TextIngestionRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    categories: list[InputCategory] = Field(default_factory=list, max_length=50)


class TextIngestionResponse(BaseModel):
    """Unpersisted draft list, always reviewed before transaction creation."""

    drafts: tuple[TransactionDraft, ...]


def get_transaction_ingestor(request: TextIngestionRequest) -> ParseTransaction:
    """Configure text parsing without persisting the resulting draft."""
    return ParseTransaction(
        NaturalTransactionParser(
            expense_categories=tuple(
                c.name for c in request.categories if not c.is_income
            )
            or None,
            income_categories=tuple(c.name for c in request.categories if c.is_income)
            or None,
        )
    )


def get_receipt_ingestor(request: Request) -> IngestReceipt:
    """Reuse the application-owned adapter and HTTP pool, never a mock receipt."""
    extractor = getattr(request.app.state, "receipt_extractor", None)
    if extractor is None or extractor.is_mock:
        raise HTTPException(
            status_code=503,
            detail=(
                "Dịch vụ đọc hóa đơn chưa được cấu hình. Hãy nhập chữ hoặc thử lại sau."
            ),
        )
    return IngestReceipt(extractor)


@router.post("/text")
async def ingest_text(
    request: TextIngestionRequest,
    user: UserDependency,
    use_case: Annotated[ParseTransaction, Depends(get_transaction_ingestor)],
) -> TextIngestionResponse:
    """Analyze authenticated input; saving still requires a transaction POST."""
    try:
        return TextIngestionResponse(drafts=await use_case.execute_many(request.text))
    except ValueError as exc:
        raise HTTPException(422, "Nội dung giao dịch không hợp lệ.") from exc


async def ingest_receipt(image: bytes, use_case: IngestReceipt) -> ReceiptData:
    """Compatibility hook for callers that already own validated image bytes."""
    return await use_case.execute(image)


def validate_receipt_image(image: bytes, mime_type: str) -> None:
    """Verify the actual format and dimensions without retaining uploaded media."""
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(image)) as picture:
                if picture.format != RECEIPT_FORMATS[mime_type]:
                    raise ValueError("Ảnh không khớp định dạng đã chọn.")
                if picture.width * picture.height > MAX_RECEIPT_PIXELS:
                    raise ValueError("Ảnh quá lớn. Hãy chọn ảnh dưới 20 megapixel.")
                if getattr(picture, "n_frames", 1) != 1:
                    raise ValueError("Hãy chọn ảnh hóa đơn tĩnh.")
                picture.verify()
            with Image.open(io.BytesIO(image)) as picture:
                picture.load()
    except (
        OSError,
        SyntaxError,
        UnidentifiedImageError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ) as exc:
        raise ValueError("Ảnh không hợp lệ hoặc bị hỏng. Hãy chọn ảnh khác.") from exc


@router.post("/receipt", response_model=TextIngestionResponse)
async def upload_receipt(
    request: Request,
    user: UserDependency,
    use_case: Annotated[IngestReceipt, Depends(get_receipt_ingestor)],
) -> TextIngestionResponse:
    """Accept raw JPEG/PNG/WebP, capped while streaming, and return one draft."""
    mime_type = request.headers.get("content-type", "").split(";", 1)[0].strip().lower()
    if mime_type not in RECEIPT_FORMATS:
        raise HTTPException(415, "Hãy chọn ảnh JPEG, PNG hoặc WebP.")
    declared = request.headers.get("content-length")
    if declared is not None:
        try:
            size = int(declared)
        except ValueError as exc:
            raise HTTPException(400, "Kích thước ảnh không hợp lệ.") from exc
        if size < 0:
            raise HTTPException(400, "Kích thước ảnh không hợp lệ.")
        if size > MAX_RECEIPT_BYTES:
            raise HTTPException(413, "Ảnh tối đa 8 MB. Hãy chọn ảnh nhỏ hơn.")
    image = bytearray()
    async for chunk in request.stream():
        if len(image) + len(chunk) > MAX_RECEIPT_BYTES:
            raise HTTPException(413, "Ảnh tối đa 8 MB. Hãy chọn ảnh nhỏ hơn.")
        image.extend(chunk)
    if not image:
        raise HTTPException(422, "Ảnh trống. Hãy chọn lại hóa đơn.")
    try:
        data = bytes(image)
        await run_in_threadpool(validate_receipt_image, data, mime_type)
        draft = await use_case.draft(data, mime_type)
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
    except CloudVLMError as exc:
        messages = {
            "timeout": "Đọc hóa đơn quá lâu. Hãy thử lại hoặc nhập chữ.",
            "quota": "Dịch vụ đọc hóa đơn đã hết lượt. Hãy thử lại sau hoặc nhập chữ.",
            "validation": "Chưa đọc rõ hóa đơn. Hãy chọn ảnh rõ hơn hoặc nhập chữ.",
            "truncated": "Chưa đọc hết hóa đơn. Hãy chụp riêng phần cần nhập.",
        }
        raise HTTPException(
            503,
            messages.get(
                exc.reason,
                "Dịch vụ đọc hóa đơn tạm thời không khả dụng. Hãy thử lại sau.",
            ),
        ) from exc
    return TextIngestionResponse(drafts=(draft,))
