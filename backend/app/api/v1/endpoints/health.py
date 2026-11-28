from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/ready/ai")
async def ai_readiness(request: Request) -> JSONResponse:
    """Report local warm-up separately from process liveness or cloud access."""
    result = getattr(
        request.app.state, "classifier_readiness", {"status": "not_warmed"}
    )
    return JSONResponse(result, status_code=200 if result["status"] == "ready" else 503)
