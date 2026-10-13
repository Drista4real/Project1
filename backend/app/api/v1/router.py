from fastapi import APIRouter

from app.api.v1.endpoints import finance, health, management, transactions
from app.api.v1.ingestion import router as ingestion_router

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(transactions.router)
api_router.include_router(finance.router)
api_router.include_router(management.router)
api_router.include_router(ingestion_router)
