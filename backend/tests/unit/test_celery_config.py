from app.workers.celery_app import celery_app


def test_celery_uses_configured_redis_and_json_serialization() -> None:
    assert celery_app.conf.broker_url == "redis://localhost:6379/0"
    assert celery_app.conf.task_serializer == "json"
    assert celery_app.conf.result_serializer == "json"
    assert celery_app.conf.accept_content == ["json"]
    assert celery_app.conf.result_accept_content == ["json"]


def test_celery_discovers_health_task() -> None:
    from app.workers.tasks.health import ping

    assert ping.name == "health.ping"
    assert "health.ping" in celery_app.tasks
