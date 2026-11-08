"""Measure local initialization, warm inference and queuing; never call cloud."""

import argparse
import json
import math
import os
import platform
import statistics
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from time import perf_counter

TEXTS = (
    "cơm sườn 35000 đồng",
    "đổ xăng 50000 đồng",
    "mua áo 200000 đồng",
    "tiền điện 300000 đồng",
    "mua thuốc 75000 đồng",
    "gửi xe 5000 đồng",
)

#: Audio containers the on-device recognizer can open.
AUDIO_SUFFIXES = (".wav", ".m4a", ".mp3")

#: A recording larger than this is not a benchmark sample.
MAX_AUDIO_BYTES = 64 * 1024 * 1024


def summarize(values: list[float]) -> dict[str, float]:
    """Use nearest-rank p95; all values include queueing and are milliseconds."""
    ordered = sorted(values)
    return {
        "p50_ms": round(statistics.median(values), 3),
        "p95_ms": round(ordered[math.ceil(0.95 * len(values)) - 1], 3),
    }


def _rebuild_from_root(path: Path) -> Path:
    """Rebuild a path from the directory entries that really exist.

    The requested name is only used to pick an entry out of a directory
    listing; the path that is returned is assembled from those entries, so
    it can never point at a location the caller invented.
    """
    absolute = path if path.is_absolute() else Path.cwd() / path
    parts = absolute.parts
    current = Path(parts[0])
    for part in parts[1:]:
        for entry in os.scandir(current):
            if entry.name == part:
                current = Path(entry.path)
                break
        else:
            raise ValueError(f"{absolute} does not exist.")
    return current


def read_audio(path: Path) -> bytes:
    """Read a recording the operator selected, or refuse it.

    The path arrives on the command line, so it is treated as untrusted
    input rather than a trusted name. The file is located by walking the
    real directory entries of the path, so the bytes always come from a
    file that exists on disk: a name that only traverses somewhere else
    never reaches the read. The recording must also be a regular file with
    a known audio extension and a size a benchmark could use.
    """
    if path.suffix.lower() not in AUDIO_SUFFIXES:
        raise ValueError(
            f"Unsupported audio format {path.suffix!r}; "
            f"expected one of {', '.join(AUDIO_SUFFIXES)}."
        )
    resolved = _rebuild_from_root(path)
    for entry in os.scandir(resolved.parent):
        if entry.name != resolved.name:
            continue
        if not entry.is_file(follow_symlinks=False):
            raise ValueError(f"{resolved} is not a regular file.")
        size = entry.stat(follow_symlinks=False).st_size
        if size > MAX_AUDIO_BYTES:
            raise ValueError(
                f"{resolved} is larger than {MAX_AUDIO_BYTES} bytes; "
                "it is not a benchmark sample."
            )
        return Path(entry.path).read_bytes()
    raise ValueError(f"{resolved} does not exist.")


def main() -> None:
    """Run from the repository root in a fresh process for cold measurements."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=30)
    parser.add_argument("--concurrency", type=int, default=1)
    parser.add_argument("--merge", action=argparse.BooleanOptionalAction, default=None)
    parser.add_argument("--threads", type=int)
    parser.add_argument(
        "--audio", type=Path, help="Optional real WAV/M4A/MP3 recording"
    )
    args = parser.parse_args()
    if not 1 <= args.runs <= 1000 or not 1 <= args.concurrency <= 32:
        parser.error("runs must be 1..1000 and concurrency must be 1..32")
    if args.threads is not None and not 1 <= args.threads <= 64:
        parser.error("threads must be 1..64")
    if args.merge is not None:
        os.environ["CLASSIFIER_LORA_MERGE"] = str(args.merge).lower()
    if args.threads is not None:
        os.environ["CLASSIFIER_CPU_THREADS"] = str(args.threads)
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    started = perf_counter()
    from app.infrastructure.ai.classifier.runtime import (
        local_classifier,
        warmup_classifier,
    )
    from app.infrastructure.config.settings import get_settings

    runtime = local_classifier()
    cold_ms = (perf_counter() - started) * 1000
    if runtime is None:
        parser.exit(
            1, "Local classifier unavailable; prepare artifacts/dependencies.\n"
        )
    ready = warmup_classifier()
    if ready["status"] != "ready":
        parser.exit(1, "Classifier warm-up failed.\n")

    def predict(index: int) -> float:
        """Vary texts so the benchmark cannot just reuse one cached prediction."""
        before = perf_counter()
        runtime.classify(TEXTS[index % len(TEXTS)])
        return (perf_counter() - before) * 1000

    started = perf_counter()
    with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        timings = list(pool.map(predict, range(args.runs)))
    elapsed = perf_counter() - started
    import torch

    settings = get_settings()
    report = {
        "python": platform.python_version(),
        "platform": platform.platform(),
        "backend": settings.classifier_backend,
        "device": settings.classifier_device,
        "lora_merged": settings.classifier_lora_merge
        if settings.classifier_backend == "lora"
        else None,
        "torch_threads": torch.get_num_threads(),
        "cold_acquire_ms": round(cold_ms, 3),
        "startup": ready,
        "runs": args.runs,
        "concurrency": args.concurrency,
        "warm": summarize(timings),
        "throughput_per_second": round(args.runs / elapsed, 2),
        "scope": "local synthetic text; not HTTP, cloud, or quality evaluation",
    }
    if args.audio is not None:
        from app.infrastructure.ai.edge_asr.recognizer import SherpaOnnxRecognizer

        started = perf_counter()
        recognizer = SherpaOnnxRecognizer(allow_mock=False)
        asr_load_ms = (perf_counter() - started) * 1000
        # Read once; no audio contents/transcripts are emitted in the report.
        try:
            audio = read_audio(args.audio)
        except (OSError, ValueError) as error:
            parser.exit(1, f"Cannot read the recording: {error}\n")
        voice_times = []
        for _ in range(min(args.runs, 10)):
            started = perf_counter()
            transcript = recognizer.transcribe(audio)
            if not transcript:
                parser.exit(1, "ASR returned an empty transcript.\n")
            runtime.classify(transcript)
            voice_times.append((perf_counter() - started) * 1000)
        report["voice"] = {
            "asr_load_ms": round(asr_load_ms, 3),
            "first_asr_plus_classifier_ms": round(voice_times[0], 3),
            "asr_plus_classifier": summarize(voice_times),
        }
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
