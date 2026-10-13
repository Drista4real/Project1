"""Authenticated text ingestion and future receipt dependency hooks."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.api.dependencies import UserDependency
from app.application.use_cases.ingest_receipt import IngestReceipt
from app.application.use_cases.parse_transaction import ParseTransaction
from app.domain.interfaces.transaction_parser_interface import TransactionDraft
from app.domain.interfaces.vlm_interface import ReceiptData
from app.infrastructure.ai.transaction_parser import NaturalTransactionParser

router = APIRouter(prefix="/api/v1/ingestion", tags=["AI ingestion"])


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


def get_receipt_ingestor() -> IngestReceipt:
    """Override in the composition root after configuring the VLM adapter."""
    raise HTTPException(status_code=503, detail="Receipt extractor is not configured")


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
    """Upload endpoint hook; add multipart limits and auth before route registration."""
    return await use_case.execute(image)
