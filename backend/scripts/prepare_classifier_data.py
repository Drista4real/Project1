"""Audit and split classifier CSVs using explicit taxonomy and source provenance."""

import argparse
import csv
import json
import sys
from pathlib import Path

if str(Path(__file__).resolve().parents[1]) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.dataset_pipeline import Source, prepare_dataset, verify_bundle  # noqa: E402


def main() -> None:
    """Prepare a new versioned bundle or verify one without loading ML libraries."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--verify", type=Path, help="Verify an existing prepared bundle"
    )
    parser.add_argument("--taxonomy", type=Path)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--source-id")
    parser.add_argument("--source-kind", choices=("synthetic", "real", "public"))
    parser.add_argument("--usage-rights")
    parser.add_argument(
        "--sources", type=Path, help="JSON list of sources; paths relative to this file"
    )
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--ambiguity-policy", choices=("quarantine", "keep_flagged"))
    parser.add_argument("--ratios", nargs=3, type=float, default=(0.7, 0.15, 0.15))
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--near-threshold", type=float, default=0.9)
    parser.add_argument("--max-near-comparisons", type=int, default=2_000_000)
    args = parser.parse_args()
    try:
        if args.verify:
            splits = verify_bundle(args.verify)
            print(
                json.dumps(
                    {
                        "verified": True,
                        "rows": {key: len(rows) for key, rows in splits.items()},
                    }
                )
            )
            return
        if not args.taxonomy or not args.output_dir or not args.ambiguity_policy:
            parser.error("--taxonomy, --output-dir and --ambiguity-policy are required")
        if args.sources:
            if any((args.input, args.source_id, args.source_kind, args.usage_rights)):
                parser.error("Use --sources OR single-source arguments")
            payload = json.loads(args.sources.read_text(encoding="utf-8"))
            if not isinstance(payload, list):
                raise ValueError("--sources must contain a JSON list")
            sources = [
                Source(
                    args.sources.parent / entry["path"],
                    entry["source_id"],
                    entry["kind"],
                    entry["usage_rights"],
                )
                for entry in payload
            ]
        else:
            if not all(
                (args.input, args.source_id, args.source_kind, args.usage_rights)
            ):
                parser.error(
                    "Supply --input, --source-id, --source-kind and --usage-rights"
                )
            sources = [
                Source(args.input, args.source_id, args.source_kind, args.usage_rights)
            ]
        manifest = prepare_dataset(
            sources,
            args.taxonomy,
            args.output_dir,
            ambiguity_policy=args.ambiguity_policy,
            ratios=tuple(args.ratios),
            seed=args.seed,
            near_threshold=args.near_threshold,
            max_near_comparisons=args.max_near_comparisons,
        )
        print(
            json.dumps(
                {
                    "dataset_id": manifest["dataset_id"],
                    "output_dir": str(args.output_dir),
                    "rows": {
                        key: value["rows"] for key, value in manifest["splits"].items()
                    },
                },
                ensure_ascii=True,
            )
        )
    except (OSError, ValueError, TypeError, KeyError, csv.Error) as error:
        parser.exit(2, f"Dataset preparation failed: {error}\n")


if __name__ == "__main__":
    main()
