"""Audit this synthetic holdout against the frozen merged source; no ML needed."""
import csv
import hashlib
import json
import sys
from collections import Counter
from difflib import SequenceMatcher
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "backend"))
from scripts.dataset_pipeline import description_key, exact_key


def read_csv(path):
    with path.open(encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def main():
    reference = ROOT / "data/prepared/model1_merged_1000_per_label_20261018/transactions.csv"
    rows = read_csv(HERE / "transactions.csv")
    baseline = read_csv(reference)
    taxonomy = ROOT / "data/taxonomy/expense_categories.v3_user_review.json"
    labels = {entry["name"] for entry in json.loads(taxonomy.read_text(encoding="utf-8"))["categories"]}
    assert len(rows) == 200 and all(set(row) == {"text", "category"} for row in rows)
    assert all(row["text"].strip() and row["category"] in labels for row in rows)
    assert len({exact_key(row["text"]) for row in rows}) == 200
    assert len({description_key(row["text"]) for row in rows}) == 200
    exact = {exact_key(row["text"]) for row in baseline}
    descriptions = {description_key(row["text"]) for row in baseline}
    assert not any(exact_key(row["text"]) in exact for row in rows)
    assert not any(description_key(row["text"]) in descriptions for row in rows)
    near = []
    keys = [description_key(row["text"]) for row in baseline]
    for index, row in enumerate(rows, 1):
        key = description_key(row["text"])
        matcher = SequenceMatcher(None, "", key, autojunk=False)
        for other_index, other_key in enumerate(keys, 1):
            matcher.set_seq1(other_key)
            if matcher.real_quick_ratio() < 0.9 or matcher.quick_ratio() < 0.9:
                continue
            score = matcher.ratio()
            if score >= 0.9:
                near.append({"evaluation_row": index, "reference_row": other_index,
                             "similarity": round(score, 6), "evaluation_text": row["text"],
                             "reference_text": baseline[other_index - 1]["text"]})
    report = {
        "rows": len(rows), "category_counts": dict(Counter(row["category"] for row in rows)),
        "reference": str(reference.relative_to(ROOT)), "reference_rows": len(baseline),
        "reference_sha256": hashlib.sha256(reference.read_bytes()).hexdigest(),
        "csv_sha256": hashlib.sha256((HERE / "transactions.csv").read_bytes()).hexdigest(),
        "taxonomy_sha256": hashlib.sha256(taxonomy.read_bytes()).hexdigest(),
        "exact_overlap": 0, "description_key_overlap": 0,
        "near_threshold": 0.9, "near_matches": near,
        "limitations": ["Lexical checks cannot prove semantic independence.",
                         "Synthetic teacher labels have not been independently reviewed.",
                         "No student predictions or teacher logits were used."],
    }
    (HERE / "audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"rows": len(rows), "near_matches": len(near), "exact_overlap": 0}))


if __name__ == "__main__":
    main()
