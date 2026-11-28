"""Cashflow forecast route; Model 2 owns every number the route returns.

The route is registered, but no forecaster is installed yet. Model 2 forecasts
from the user's own daily balance history, which the backend does not read
yet, so the dependency returns `None` and the route answers 503 with an
actionable message. It never returns an estimated forecast.

The dependency reports absence by returning `None` rather than raising, so the
route owns the status code and can document it in OpenAPI.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from app.application.use_cases.cashflow_forecast import ForecastCashflow, IncomeType
from app.domain.interfaces.forecaster_interface import BalancePoint, CashflowForecast

router = APIRouter(prefix="/api/v1/forecast", tags=["Cashflow forecast"])

#: Told to the caller while the forecaster cannot run.
FORECAST_UNAVAILABLE = "Dự báo dòng tiền chưa sẵn sàng. Vui lòng thử lại sau."

#: Told to the caller when the supplied balance series cannot be forecast.
INVALID_HISTORY = "Lịch sử số dư không đủ hoặc không hợp lệ để dự báo."

#: The largest balance series the route accepts: one year of daily points.
MAX_HISTORY_POINTS = 366


class CashflowRequest(BaseModel):
    """The observed balance series and the income profile to forecast for."""

    model_config = ConfigDict(extra="forbid")

    history: list[BalancePoint] = Field(min_length=1, max_length=MAX_HISTORY_POINTS)
    income_type: IncomeType
    horizon_days: int = Field(default=30, ge=1, le=365)


def get_cashflow_forecaster() -> ForecastCashflow | None:
    """Return the installed Model 2 forecaster, or None while there is none.

    The composition root owns this wiring. Model 2 forecasts from the user's
    own daily balance history, which the backend does not read yet, so no
    forecaster is installed and the route reports 503 instead of raising or
    inventing numbers.
    """
    return None


@router.post(
    "",
    response_model=CashflowForecast,
    responses={503: {"description": "The cashflow forecaster is not available."}},
)
def forecast_cashflow(
    request: CashflowRequest,
    use_case: Annotated[
        ForecastCashflow | None, Depends(get_cashflow_forecaster)
    ],
) -> CashflowForecast | JSONResponse:
    """Forecast the coming days from the given balance series."""
    if use_case is None:
        return JSONResponse(status_code=503, content={"detail": FORECAST_UNAVAILABLE})
    try:
        return use_case.execute(
            request.history, request.income_type, request.horizon_days
        )
    except ValueError as error:
        raise HTTPException(422, INVALID_HISTORY) from error
