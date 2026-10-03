from fastapi import APIRouter

from app.api.dependencies import FinanceDependency
from app.domain.finance import AccountSummary, CategorySummary, FinancialOverview

router = APIRouter(prefix="/api/v1", tags=["Finance"])


@router.get("/categories", response_model=list[CategorySummary])
def categories(service: FinanceDependency):
    return service.categories()


@router.get("/accounts", response_model=list[AccountSummary])
def accounts(service: FinanceDependency):
    return service.accounts()


@router.get("/overview", response_model=FinancialOverview)
def overview(service: FinanceDependency):
    return service.overview()
