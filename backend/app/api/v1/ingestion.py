"""FastAPI ingestion router skeleton with application dependency hooks."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.application.use_cases.ingest_receipt import IngestReceipt
from app.application.use_cases.ingest_transaction import (
    IngestTransaction,
    IngestTransactionResult,
)
from app.domain.interfaces.vlm_interface import ReceiptData

router = APIRouter(prefix="/api/v1/ingestion", tags=["AI ingestion"])


class TextIngestionRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


def get_transaction_ingestor() -> IngestTransaction:
    """Override in the composition root after configuring model adapters."""
    raise HTTPException(status_code=503, detail="AI classifier is not configured")


def get_receipt_ingestor() -> IngestReceipt:
    """Override in the composition root after configuring the VLM adapter."""
    raise HTTPException(status_code=503, detail="Receipt extractor is not configured")


@router.post("/text")
def ingest_text(
    request: TextIngestionRequest,
    use_case: Annotated[IngestTransaction, Depends(get_transaction_ingestor)],
) -> IngestTransactionResult:
    return use_case.execute(request.text)


async def ingest_receipt(image: bytes, use_case: IngestReceipt) -> ReceiptData:
    """Upload endpoint hook; add multipart limits and auth before route registration."""
    return await use_case.execute(image)
