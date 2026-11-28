"""Check shared runtime concurrency and warm-up without optional ML libraries."""

from concurrent.futures import ThreadPoolExecutor
from threading import Event, Lock
from unittest.mock import Mock

from app.domain.interfaces.classifier_interface import ClassificationResult
from app.infrastructure.ai.classifier import runtime


def test_warmup_runs_once_and_does_not_retain_text() -> None:
    """Warm-up is idempotent and subsequent predictions still run normally."""
    adapter = Mock()
    shared = runtime.ClassifierRuntime(adapter, 12.0)
    shared.warmup()
    shared.warmup()
    adapter.classify.assert_called_once()
    assert shared.warmup_ms is not None
    shared.classify("another input")
    assert adapter.classify.call_count == 2


def test_concurrent_inference_does_not_overlap() -> None:
    """A second request waits instead of running another CPU thread pool."""
    entered = Event()
    release = Event()
    lock = Lock()
    active = 0
    peak = 0

    def classify(text: str) -> ClassificationResult:
        nonlocal active, peak
        with lock:
            active += 1
            peak = max(peak, active)
        entered.set()
        assert release.wait(5)
        with lock:
            active -= 1
        return ClassificationResult("Khác", 0.9)

    shared = runtime.ClassifierRuntime(Mock(classify=classify), 0)
    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(shared.classify, "one")
        assert entered.wait(5)
        second = pool.submit(shared.classify, "two")
        release.set()
        assert first.result().label == second.result().label
    assert peak == 1


def test_parallel_cache_misses_load_one_model(monkeypatch) -> None:
    """The loader guard serializes cache misses as well as inference."""
    runtime._load_local_classifier.cache_clear()
    loader = Mock(return_value=object())
    monkeypatch.setattr(runtime, "_load_local_classifier", runtime.lru_cache(1)(loader))
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: runtime.local_classifier(), range(12)))
    assert all(result is results[0] for result in results)
    loader.assert_called_once()


def test_failed_warmup_is_reported_without_cloud(monkeypatch) -> None:
    """A loadable but broken model cannot claim warmed readiness."""
    shared = runtime.ClassifierRuntime(
        Mock(classify=Mock(side_effect=RuntimeError("broken"))), 5
    )
    monkeypatch.setattr(runtime, "local_classifier", lambda: shared)
    assert runtime.warmup_classifier() == {
        "status": "unavailable",
        "load_ms": 5,
        "warmup_ms": None,
    }
