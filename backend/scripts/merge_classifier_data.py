"""Merge the five supplied Model 1 sources and build a portable audited bundle.

Only standard-library dependencies are needed. Supplied labels are retained as
`provided`, which permits development use without claiming annotation approval.
"""

from __future__ import annotations

import argparse
import csv
import json
import shutil
from collections import Counter
from pathlib import Path

from dataset_pipeline import (
    Source,
    Taxonomy,
    digest,
    exact_key,
    prepare_dataset,
    write_json,
)

ROOT = Path(__file__).resolve().parents[2]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream, strict=True)
        if not {"text", "category"}.issubset(reader.fieldnames or []):
            raise ValueError(f"Missing text/category columns: {path}")
        rows = list(reader)
    if not rows or any(
        None in row or any(v is None for v in row.values()) for row in rows
    ):
        raise ValueError(f"Empty or malformed source: {path}")
    return rows


def write_csv(path: Path, rows: list[dict[str, str]], columns: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def merge(teacher_dir: Path, imports_dir: Path, output: Path) -> dict:
    taxonomy_path = ROOT / "data/taxonomy/expense_categories.v2_defaults.json"
    taxonomy = Taxonomy.load(taxonomy_path)
    teacher = read_csv(teacher_dir / "transactions_with_provenance.csv")
    plain_teacher = read_csv(teacher_dir / "transactions.csv")
    if [(r["text"], r["category"]) for r in teacher] != [
        (r["text"], r["category"]) for r in plain_teacher
    ]:
        raise ValueError("Teacher CSV and provenance CSV differ")
    inputs = [("teacher", teacher_dir / "transactions_with_provenance.csv", teacher)]
    inputs += [
        (
            f"contributor_{i:02}",
            imports_dir / f"{i:02}.csv",
            read_csv(imports_dir / f"{i:02}.csv"),
        )
        for i in range(1, 5)
    ]
    expected = Counter({label: 200 for label in taxonomy.labels})
    for source_id, path, rows in inputs:
        if Counter(r["category"] for r in rows) != expected:
            raise ValueError(f"{source_id}: expected 200 rows per taxonomy label")
        if any(not r["text"].strip() for r in rows):
            raise ValueError(f"{path}: empty text")
    if output.exists() and any(output.iterdir()):
        raise ValueError("Output directory is not empty; choose a new version")
    originals = output / "originals"
    enriched = output / "sources"
    originals.mkdir(parents=True)
    enriched.mkdir()
    sources, declarations, merged, inventory = [], [], [], []
    for source_id, path, rows in inputs:
        raw_path = originals / (
            "teacher_with_provenance.csv" if source_id == "teacher" else path.name
        )
        shutil.copyfile(path, raw_path)
        kind = "synthetic" if source_id == "teacher" else "public"
        rights = (
            "Original AI-generated teacher data; see original generation.json."
            if source_id == "teacher"
            else "User supplied labeled CSV scraped by a contributor for Model 1. "
            "Public-source classification is provisional; URLs, collection method, "
            "license, real/synthetic origin and independent review were not supplied. "
            "Local development use requested; redistribution rights not verified."
        )
        prepared = []
        for line, row in enumerate(rows, 2):
            item = dict(row)
            if source_id != "teacher":
                item.update(
                    record_id=f"{source_id}_{line - 1:04}",
                    transaction_type="expense",
                    annotation_status="provided",
                    annotator_id="",
                    annotation_note="Supplied label; no independent review.",
                )
            prepared.append(item)
            merged.append({**item, "source_id": source_id, "source_row": str(line)})
        columns = list(dict.fromkeys(key for row in prepared for key in row))
        source_path = enriched / f"{source_id}.csv"
        write_csv(source_path, prepared, columns)
        sources.append(Source(source_path, source_id, kind, rights))
        declarations.append(
            dict(
                path=f"sources/{source_id}.csv",
                source_id=source_id,
                kind=kind,
                usage_rights=rights,
            )
        )
        inventory.append(
            dict(
                source_id=source_id,
                original=f"originals/{raw_path.name}",
                sha256=digest(path.read_bytes()),
                rows=len(rows),
                category_counts=dict(Counter(r["category"] for r in rows)),
            )
        )
    shutil.copyfile(
        teacher_dir / "generation.json", originals / "teacher_generation.json"
    )
    write_json(output / "sources.json", declarations)
    write_csv(output / "transactions.csv", merged, ["text", "category"])
    write_csv(
        output / "transactions_with_provenance.csv",
        merged,
        list(dict.fromkeys(key for row in merged for key in row)),
    )
    manifest = prepare_dataset(
        sources,
        taxonomy_path,
        output / "bundle_v1",
        ambiguity_policy="quarantine",
        seed=42,
        max_near_comparisons=20_000_000,
    )
    audit = json.loads((output / "bundle_v1/audit.json").read_text(encoding="utf-8"))
    report = dict(
        schema_version=1,
        date="2026-10-18",
        issue=31,
        rows=len(merged),
        category_counts=dict(Counter(r["category"] for r in merged)),
        unique_normalized_texts=len({exact_key(r["text"]) for r in merged}),
        sources=inventory,
        dataset_id=manifest["dataset_id"],
        eligible_category_counts=audit["eligible_category_counts"],
        review_rows=audit["review_rows"],
        review_reasons=audit["review_reasons"],
        duplicates_removed=audit["duplicates_removed"],
        splits={
            k: {"rows": v["rows"], "category_counts": v["category_counts"]}
            for k, v in manifest["splits"].items()
        },
        sha256={
            name: digest((output / name).read_bytes())
            for name in (
                "transactions.csv",
                "transactions_with_provenance.csv",
                "sources.json",
            )
        },
    )
    write_json(output / "validation_report.json", report)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--teacher-dir",
        type=Path,
        default=ROOT / "data/synthetic/model1_teacher_200_per_label_20261017",
    )
    parser.add_argument(
        "--imports-dir",
        type=Path,
        required=True,
        help="Directory containing 01.csv through 04.csv",
    )
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    report = merge(args.teacher_dir, args.imports_dir, args.output_dir)
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
