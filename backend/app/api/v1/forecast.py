"""FastAPI cashflow router skeleton delegating to the application use case."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.application.use_cases.cashflow_forecast import ForecastCashflow, IncomeType
from app.domain.interfaces.forecaster_interface import BalancePoint, CashflowForecast

router = APIRouter(prefix="/api/v1/forecast", tags=["Cashflow forecast"])


class CashflowRequest(BaseModel):
    history: list[BalancePoint] = Field(min_length=1)
    income_type: IncomeType
    horizon_days: int = Field(default=30, ge=1, le=365)


def get_cashflow_forecaster() -> ForecastCashflow:
    """Override in the composition root after configuring both income adapters."""
    raise HTTPException(status_code=503, detail="Cashflow forecaster is not configured")


@router.post("")
def forecast_cashflow(
    request: CashflowRequest,
    use_case: Annotated[ForecastCashflow, Depends(get_cashflow_forecaster)],
) -> CashflowForecast:
    return use_case.execute(request.history, request.income_type, request.horizon_days)
