"""Reload a trained LoRA artifact and classify text without calling a cloud API."""

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "backend") not in sys.path:
    sys.path.insert(0, str(ROOT / "backend"))

from app.infrastructure.ai.classifier.lora import LoRAClassifier  # noqa: E402


def main() -> None:
    """Load the saved tokenizer, adapter, head and frozen base revision."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-dir", required=True, type=Path)
    parser.add_argument("--text", required=True)
    parser.add_argument("--device", default="cpu", choices=("cpu", "cuda"))
    parser.add_argument("--cache-dir", type=Path)
    parser.add_argument("--local-files-only", action="store_true")
    args = parser.parse_args()
    classifier = LoRAClassifier(
        args.artifact_dir,
        device=args.device,
        cache_dir=args.cache_dir,
        local_files_only=args.local_files_only,
    )
    print(json.dumps(classifier.predict(args.text), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
