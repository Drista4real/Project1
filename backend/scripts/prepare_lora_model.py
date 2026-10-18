"""Prepare the configured LoRA base cache and verify offline backend inference."""

import argparse
import json
import sys
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))

from app.infrastructure.config.settings import get_settings  # noqa: E402


def main() -> None:
    """Download the pinned base once, then require offline artifact reload."""
    sys.stdout.reconfigure(encoding="utf-8")
    settings = get_settings()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--artifact-dir", type=Path, default=settings.classifier_lora_dir
    )
    parser.add_argument(
        "--cache-dir", type=Path, default=settings.classifier_lora_cache_dir
    )
    parser.add_argument(
        "--device", choices=("cpu", "cuda"), default=settings.classifier_device
    )
    parser.add_argument("--local-files-only", action="store_true")
    args = parser.parse_args()
    from app.infrastructure.ai.classifier.lora import LoRAClassifier

    print(f"Preparing LoRA: {args.artifact_dir}", flush=True)
    started = perf_counter()
    classifier = LoRAClassifier(
        args.artifact_dir,
        device=args.device,
        cache_dir=args.cache_dir,
        local_files_only=args.local_files_only,
    )
    # Reload after preparation to verify the runtime never needs a download.
    del classifier
    classifier = LoRAClassifier(
        args.artifact_dir,
        device=args.device,
        cache_dir=args.cache_dir,
        local_files_only=True,
    )
    load_seconds = perf_counter() - started
    classifier.classify("ăn trưa 40k")
    started = perf_counter()
    result = classifier.classify("ăn trưa 40k")
    report = {
        "base_model": classifier.metadata["base_model"],
        "base_revision": classifier.metadata["base_revision"],
        "device": args.device,
        "offline_verified": True,
        "category": result.label,
        "confidence": result.confidence,
        "setup_and_reload_seconds": round(load_seconds, 2),
        "warm_prediction_ms": round((perf_counter() - started) * 1000, 2),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    main()
