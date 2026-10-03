from celery import Celery

from app.infrastructure.config.settings import get_settings

settings = get_settings()

celery_app = Celery(
    "kakeibo",
    broker=str(settings.redis_url),
    include=["app.workers.tasks.health"],
)
celery_app.conf.update(
    accept_content=["json"],
    result_accept_content=["json"],
    result_serializer="json",
    task_serializer="json",
)
