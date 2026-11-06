"""One offline classifier per process, shared by API requests and the demo."""

import logging
from functools import lru_cache
from threading import Lock
from time import perf_counter

from app.domain.interfaces.classifier_interface import (
    ClassificationResult,
    ITransactionClassifier,
)
from app.infrastructure.config.settings import get_settings

logger = logging.getLogger(__name__)
_LOAD_LOCK = Lock()


class ClassifierRuntime(ITransactionClassifier):
    """Serialize CPU inference instead of multiplying thread pools per request."""

    def __init__(self, classifier: ITransactionClassifier, load_ms: float) -> None:
        """Own the adapter and keep only aggregate operational timings."""
        self.classifier = classifier
        self.load_ms = load_ms
        self.warmup_ms: float | None = None
        self._lock = Lock()

    def classify(self, text: str) -> ClassificationResult:
        """Wait for the shared model without retaining transaction contents."""
        queued = perf_counter()
        with self._lock:
            started = perf_counter()
            result = self.classifier.classify(text)
            logger.debug(
                "Classifier queue_ms=%.2f inference_ms=%.2f",
                (started - queued) * 1000,
                (perf_counter() - started) * 1000,
            )
            return result

    def warmup(self) -> None:
        """Initialize tokenizer/segmentation and kernels once, using synthetic text."""
        with self._lock:
            if self.warmup_ms is None:
                started = perf_counter()
                self.classifier.classify("cơm sườn 35000 đồng")
                self.warmup_ms = (perf_counter() - started) * 1000


@lru_cache(maxsize=1)
def _load_local_classifier() -> ClassifierRuntime | None:
    """Load local artifacts only; optional ML dependencies may be absent."""
    settings = get_settings()
    started = perf_counter()
    try:
        if settings.classifier_cpu_threads is not None:
            import torch

            torch.set_num_threads(settings.classifier_cpu_threads)
        if settings.classifier_backend == "lora":
            from app.infrastructure.ai.classifier.lora import LoRAClassifier

            adapter = LoRAClassifier(
                settings.classifier_lora_dir,
                device=settings.classifier_device,
                cache_dir=settings.classifier_lora_cache_dir,
                local_files_only=True,
                merge_adapter=settings.classifier_lora_merge,
            )
        else:
            from app.infrastructure.ai.classifier.lgbm_inference import (
                LightGBMTransactionClassifier,
            )

            adapter = LightGBMTransactionClassifier()
        runtime = ClassifierRuntime(adapter, (perf_counter() - started) * 1000)
        logger.info(
            "Local classifier loaded backend=%s load_ms=%.2f",
            settings.classifier_backend,
            runtime.load_ms,
        )
        return runtime
    except (ImportError, OSError, RuntimeError, ValueError):
        logger.warning(
            "Local classifier %s unavailable; transaction drafts need review",
            settings.classifier_backend,
            exc_info=True,
        )
        return None


def local_classifier() -> ClassifierRuntime | None:
    """Guard cache misses so concurrent requests cannot load duplicate models."""
    with _LOAD_LOCK:
        return _load_local_classifier()


def warmup_classifier() -> dict[str, str | float | None]:
    """Warm locally without cloud calls; expose degraded availability honestly."""
    runtime = local_classifier()
    if runtime is None:
        return {"status": "unavailable", "load_ms": None, "warmup_ms": None}
    try:
        runtime.warmup()
    except (OSError, RuntimeError, ValueError):
        logger.warning("Classifier warm-up failed", exc_info=True)
        return {
            "status": "unavailable",
            "load_ms": runtime.load_ms,
            "warmup_ms": None,
        }
    return {
        "status": "ready",
        "load_ms": runtime.load_ms,
        "warmup_ms": runtime.warmup_ms,
    }
