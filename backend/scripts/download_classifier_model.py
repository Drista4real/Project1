"""Prepare PhoBERT for the existing Model 1 checkpoint without training."""

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "backend") not in sys.path:
    sys.path.insert(0, str(ROOT / "backend"))

from app.infrastructure.ai.classifier.config import (  # noqa: E402
    CHECKPOINT_DIR,
    MODEL_CACHE_DIR,
    ClassifierConfig,
)


def prepare_model(
    config_path: Path,
    cache_dir: Path,
    *,
    local_files_only: bool = False,
) -> str:
    """Populate the shared cache, then verify it with downloads disabled."""
    # Validate metadata before loading optional NLP dependencies or downloading.
    config = ClassifierConfig.load(config_path)
    from app.infrastructure.ai.classifier.phobert_embedder import PhoBERTEmbedder

    print(f"Preparing {config.model_name} @ {config.revision}", flush=True)
    embedder = PhoBERTEmbedder(
        config=config, cache_dir=cache_dir, local_files_only=local_files_only
    )
    resolved_revision = embedder.config.revision
    del embedder
    # Reload with the original configuration: this is how inference finds files,
    # including the cached branch reference when metadata still specifies main.
    offline = PhoBERTEmbedder(config=config, cache_dir=cache_dir, local_files_only=True)
    vector = offline.embed("ăn trưa 40k")
    if vector.shape != (config.embedding_dim,):
        raise RuntimeError("PhoBERT verification returned an unexpected vector shape")
    print(f"PhoBERT ready: {cache_dir.resolve()}")
    print(f"Resolved revision: {resolved_revision}")
    print("Offline embedding verified (768 features). No training performed.")
    return resolved_revision


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config", type=Path, default=CHECKPOINT_DIR / "classifier_config.json"
    )
    parser.add_argument("--cache-dir", type=Path, default=MODEL_CACHE_DIR)
    parser.add_argument(
        "--local-files-only",
        action="store_true",
        help="Verify an existing cache without downloading anything.",
    )
    args = parser.parse_args()
    try:
        prepare_model(
            args.config, args.cache_dir, local_files_only=args.local_files_only
        )
    except ImportError as error:
        parser.exit(
            1,
            f"Missing NLP dependency: {error}\nInstall with: "
            "python -m pip install -r backend/requirements-classifier.txt\n",
        )
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(
            1,
            f"PhoBERT setup failed: {error}\n"
            "Check the classifier config, cache permissions and available disk "
            "space. If files are missing, retry with Internet access and without "
            "--local-files-only.\n",
        )


if __name__ == "__main__":
    main()
