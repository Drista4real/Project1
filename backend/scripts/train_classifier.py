"""Train PhoBERT CLS + LightGBM for six Vietnamese transaction categories."""

# Imports follow the path bootstrap for direct execution from any directory.
# ruff: noqa: E402

import argparse
import csv
import logging
import pickle
import sys
from collections import Counter
from io import TextIOWrapper
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parents[2]
# Support both `python backend/scripts/train_classifier.py` and module execution.
if str(ROOT / "backend") not in sys.path:
    sys.path.insert(0, str(ROOT / "backend"))

import numpy as np
from lightgbm import LGBMClassifier
from lightgbm.basic import LightGBMError
from sklearn.metrics import classification_report, f1_score
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

from app.infrastructure.ai.classifier.config import (
    CATEGORIES,
    CONFIDENCE_THRESHOLD,
    MODEL_CACHE_DIR,
)
from app.infrastructure.ai.classifier.phobert_embedder import PhoBERTEmbedder

logger = logging.getLogger(__name__)


def load_dataset(data_path: Path) -> tuple[list[str], list[str]]:
    """Read UTF-8 CSV and reject missing values, unknown labels, and sparse classes."""
    texts: list[str] = []
    categories: list[str] = []
    try:
        with data_path.open(encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            if set(reader.fieldnames or []) != {"text", "category"}:
                raise ValueError("CSV must contain exactly the columns text,category")
            for line, row in enumerate(reader, start=2):
                text = row.get("text")
                category = row.get("category")
                if (
                    None in row
                    or not isinstance(text, str)
                    or not text.strip()
                    or not isinstance(category, str)
                    or category.strip() not in CATEGORIES
                ):
                    raise ValueError(f"Invalid text or category at CSV row {line}")
                texts.append(text)
                categories.append(category.strip())
    except FileNotFoundError as exc:
        raise FileNotFoundError(
            f"Training data not found: {data_path}. Provide a text,category CSV."
        ) from exc
    except (csv.Error, UnicodeError) as exc:
        raise ValueError(f"Cannot parse UTF-8 training data: {data_path}") from exc
    counts = Counter(categories)
    if set(counts) != set(CATEGORIES) or any(count < 2 for count in counts.values()):
        raise ValueError("Dataset must contain all six categories with >= 2 rows each")
    return texts, categories


def train(
    data_path: Path,
    output_dir: Path,
    *,
    batch_size: int = 16,
    cache_dir: Path = MODEL_CACHE_DIR,
    local_files_only: bool = False,
) -> None:
    """Train on a stratified 80/20 split, evaluate, and save three artifacts."""
    if batch_size < 1:
        raise ValueError("batch_size must be positive")
    texts, categories = load_dataset(data_path)
    encoder = LabelEncoder().fit(list(CATEGORIES))
    labels = encoder.transform(categories)
    try:
        train_texts, test_texts, y_train, y_test = train_test_split(
            texts, labels, test_size=0.2, stratify=labels, random_state=42
        )
    except ValueError as exc:
        raise ValueError(
            "Dataset is too small for a six-class stratified 80/20 split"
        ) from exc
    embedder = PhoBERTEmbedder(cache_dir=cache_dir, local_files_only=local_files_only)
    logger.info(
        "Extracting CPU CLS features: train=%d test=%d", len(y_train), len(y_test)
    )
    x_train = embedder.embed_batch(train_texts, batch_size=batch_size)
    x_test = embedder.embed_batch(test_texts, batch_size=batch_size)
    model = LGBMClassifier(
        n_estimators=100,
        learning_rate=0.05,
        objective="multiclass",
        random_state=42,
        verbosity=-1,
    )
    model.fit(x_train, y_train)
    # One thread avoids OpenMP overhead for individual transaction predictions.
    model.set_params(n_jobs=1)
    predictions = model.predict(x_test)
    probabilities = model.predict_proba(x_test)
    macro_f1 = float(f1_score(y_test, predictions, average="macro", zero_division=0))
    local_rate = float(np.mean(np.max(probabilities, axis=1) >= CONFIDENCE_THRESHOLD))
    print(
        classification_report(
            y_test,
            predictions,
            labels=np.arange(len(CATEGORIES)),
            target_names=encoder.classes_,
            zero_division=0,
        )
    )
    print(f"Macro F1-Score: {macro_f1:.4f}")
    print(f"Local handling rate (P >= 0.8): {local_rate:.2%}")
    # Measure actual single-sentence CPU latency, including segmentation and PhoBERT.
    probe_texts = test_texts[: min(50, len(test_texts))]
    embedder.embed(probe_texts[0])
    latencies: list[float] = []
    for text in probe_texts:
        start = perf_counter()
        model.predict_proba(embedder.embed(text).reshape(1, -1))
        latencies.append((perf_counter() - start) * 1000)
    print(
        f"CPU latency ({len(latencies)} warm samples): "
        f"mean={np.mean(latencies):.2f}ms, p95={np.percentile(latencies, 95):.2f}ms"
    )
    output_dir.mkdir(parents=True, exist_ok=True)
    try:
        for filename, artifact in (
            ("lgbm_classifier.pkl", model),
            ("label_encoder.pkl", encoder),
        ):
            with (output_dir / filename).open("wb") as stream:
                pickle.dump(artifact, stream, protocol=pickle.HIGHEST_PROTOCOL)
        embedder.config.save(output_dir / "classifier_config.json")
    except OSError as exc:
        raise RuntimeError(f"Cannot save classifier artifacts to {output_dir}") from exc
    logger.info("Saved classifier, label encoder, and feature config to %s", output_dir)


def main() -> None:
    """Parse CLI options and report actionable training failures."""
    # Vietnamese category names cannot be printed with Windows' legacy code pages.
    if isinstance(sys.stdout, TextIOWrapper):
        sys.stdout.reconfigure(encoding="utf-8")
    if isinstance(sys.stderr, TextIOWrapper):
        sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--data", type=Path, default=ROOT / "data/processed/data_transactions.csv"
    )
    parser.add_argument("--output-dir", type=Path, default=ROOT / "weights/checkpoints")
    parser.add_argument("--cache-dir", type=Path, default=MODEL_CACHE_DIR)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--local-files-only", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    try:
        train(
            args.data,
            args.output_dir,
            batch_size=args.batch_size,
            cache_dir=args.cache_dir,
            local_files_only=args.local_files_only,
        )
    except (OSError, ValueError, RuntimeError, TypeError, LightGBMError) as exc:
        logger.error("Training failed: %s", exc)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
