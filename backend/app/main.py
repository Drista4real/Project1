from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse

from app.api.v1.router import api_router
from app.domain.transactions import TransactionError
from app.infrastructure.config.settings import get_settings

app = FastAPI(title="Kakeibo API", version="1.0.0")
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
