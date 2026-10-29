import asyncio
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse

from app.api.v1.router import api_router
from app.domain.transactions import TransactionError
from app.infrastructure.ai.classifier.runtime import warmup_classifier
from app.infrastructure.ai.cloud_vlm.qwen_client import QwenVLMReceiptExtractor
from app.infrastructure.config.settings import get_settings

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Prepare local inference and own the receipt connection pool per worker."""
    app.state.classifier_readiness = {"status": "not_warmed"}
    if get_settings().classifier_warmup:
        app.state.classifier_readiness = await asyncio.to_thread(warmup_classifier)
    try:
        extractor = QwenVLMReceiptExtractor()
    except ValueError:
        logger.warning("Receipt extractor configuration invalid; receipts unavailable")
        extractor = None
    app.state.receipt_extractor = extractor
    try:
        yield
    finally:
        if extractor is not None:
            await extractor.aclose()


app = FastAPI(title="Kakeibo API", version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origins,
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
app.include_router(api_router)


@app.get("/", include_in_schema=False)
def index():
    return RedirectResponse(url="/docs")


@app.exception_handler(TransactionError)
async def transaction_error_handler(request, error: TransactionError):
    return JSONResponse(status_code=error.status, content={"detail": error.message})
