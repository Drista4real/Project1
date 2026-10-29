"""Dataset integrity tests run without model downloads, cloud calls or training."""

import csv
import json
import random
import subprocess
import sys
from collections import Counter
from pathlib import Path

import pytest

from scripts.dataset_pipeline import (
    Source,
    Taxonomy,
    audit_records,
    description_key,
    digest,
    group_records,
    prepare_dataset,
    read_sources,
    split_records,
    verify_bundle,
)

ROOT = Path(__file__).resolve().parents[2]
TAXONOMY = ROOT / "data/taxonomy/expense_categories.v1.json"


def test_user_scope_approval_is_limited_to_exact_text_and_category(
    tmp_path: Path,
) -> None:
    """Nine explicit decisions resolve only the scope flag, preserving other checks."""
    policy = ROOT / "data/taxonomy/expense_categories.v3_user_review.json"
    payload = json.loads(policy.read_text(encoding="utf-8"))
    rows = [{"text": e["text"], "category": e["category"],
             "annotation_status": "approved"}
            for e in payload["approved_scope_exceptions"]]
    path = write_input(tmp_path / "approved.csv", rows)
    records, _ = read_sources(
        [Source(path, "user-reviewed", "public", "user supplied")]
    )
    eligible, review, _ = audit_records(records, Taxonomy.load(policy), "quarantine")
    assert len(eligible) == 9
    assert not review
    records, _ = read_sources(
        [Source(path, "user-reviewed", "public", "user supplied")]
    )
    _, old_review, _ = audit_records(records, Taxonomy.load(TAXONOMY), "quarantine")
    assert len(old_review) == 9
    rows = [
        {"text": "vay tien ngan hang 500k", "category": rows[0]["category"]},
        {"text": rows[0]["text"], "category": "unknown"},
        {**rows[1], "annotation_status": "pending"},
    ]
    write_input(path, rows)
    records, _ = read_sources([Source(path, "fixture", "synthetic", "test")])
    eligible, review, audit = audit_records(
        records, Taxonomy.load(policy), "quarantine"
    )
    assert not eligible
    assert len(review) == 3
    assert audit["review_reasons"]["possible_income_transfer_or_debt"] == 2
    assert audit["review_reasons"]["annotation_pending"] == 1


def test_scope_approval_requires_documented_user_decision(tmp_path: Path) -> None:
    payload = json.loads(TAXONOMY.read_text(encoding="utf-8"))
    payload["approved_scope_exceptions"] = [{"text": "vay 20k", "category": "unknown"}]
    path = tmp_path / "invalid.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(ValueError, match="Scope exceptions require"):
        Taxonomy.load(path)


def test_supplied_labels_keep_unreviewed_status_and_still_obey_audit(
    tmp_path: Path,
) -> None:
    """Development ingestion must not claim approval or bypass conflict checks."""
    rows = examples()[:3]
    for row in rows:
        row["annotation_status"] = "provided"
    path = write_input(tmp_path / "provided.csv", rows)
    records, _ = read_sources([Source(path, "contributor", "public", "user supplied")])
    eligible, review, _ = audit_records(records, Taxonomy.load(TAXONOMY), "quarantine")
    assert len(eligible) == 3
    assert not review
    assert {r.annotation_status for r in eligible} == {"provided"}
    assert all(r.origins[0]["annotation_status"] == "provided" for r in eligible)
    rows.append({**rows[0], "category": "unknown"})
    write_input(path, rows)
    records, _ = read_sources([Source(path, "contributor", "public", "user supplied")])
    _, review, audit = audit_records(records, Taxonomy.load(TAXONOMY), "quarantine")
    assert len(review) == 2
    assert audit["review_reasons"]["conflicting_annotation"] == 2


def test_near_comparison_limit_is_explicit_and_never_skips_pairs(
    tmp_path: Path,
) -> None:
    """Increasing the budget permits work; exhausting it still fails closed."""
    label = next(iter(Taxonomy.load(TAXONOMY).labels))
    path = write_input(tmp_path / "similar.csv", [
        {"text": "abcdefghij 10k", "category": label},
        {"text": "abcdxfghij 20k", "category": label},
    ])
    records, _ = read_sources([Source(path, "fixture", "synthetic", "test")])
    with pytest.raises(ValueError, match="budget exceeded"):
        group_records(records, 0.9, max_near_comparisons=0)
    audit = group_records(records, 0.9, max_near_comparisons=10)
    assert audit["near_candidate_comparisons"] == 1
    assert audit["groups"] == 1


def write_input(path: Path, rows: list[dict[str, str]]) -> Path:
    """Write a CSV fixture using the union of its declared columns."""
    columns = sorted(set().union(*(row.keys() for row in rows)))
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns)
        writer.writeheader()
        writer.writerows(rows)
    return path


def examples() -> list[dict[str, str]]:
    """Create independently named groups, each with two money variants per label."""
    labels = Taxonomy.load(TAXONOMY).labels
    rng = random.Random(2026)
    rows = []
    for category in labels:
        for _ in range(14):
            name = "".join(rng.choices("abcdefghijklmnopqrstuvwxyz", k=18))
            for amount in (35, 65):
                rows.append({"text": f"{name} {amount}k", "category": category})
    return rows


def prepare(tmp_path: Path, rows: list[dict[str, str]], **kwargs: object) -> Path:
    """Build an isolated synthetic bundle with an explicit rights declaration."""
    source = Source(
        write_input(tmp_path / "source.csv", rows),
        "fixture",
        "synthetic",
        "test fixture",
    )
    output = tmp_path / "prepared"
    prepare_dataset([source], TAXONOMY, output, ambiguity_policy="quarantine", **kwargs)
    return output


def test_taxonomy_matches_legacy_labels_and_encoded_order() -> None:
    """The agreed taxonomy must not silently change existing checkpoint labels."""
    from app.infrastructure.ai.classifier.config import CATEGORIES

    taxonomy = Taxonomy.load(TAXONOMY)
    payload = json.loads(TAXONOMY.read_text(encoding="utf-8"))
    assert set(taxonomy.labels) == set(CATEGORIES)
    for entry in payload["categories"]:
        assert sorted(CATEGORIES)[entry["legacy_encoded_id"]] == entry["name"]


@pytest.mark.parametrize(
    "texts",
    [
        ("Cơm sườn 35k", "com suon 65 cành", "cơm sườn 1 củ rưỡi"),
        ("mua đồ 3tr5", "mua đồ 500 cành", "mua đồ 2 củ rưỡi"),
        ("trà sữa 15k", "tra sua 1.500.000 đồng", "trà sữa 5 xị"),
    ],
)
def test_money_and_accent_variants_share_description_key(
    texts: tuple[str, ...],
) -> None:
    """Changing the amount/accent does not create an independent test example."""
    assert len({description_key(text) for text in texts}) == 1


def test_bundle_is_disjoint_and_covers_every_label(tmp_path: Path) -> None:
    """Every class is represented; neither money variants nor IDs leak across splits."""
    rows = examples()
    original = write_input(tmp_path / "original.csv", rows).read_bytes()
    output = prepare(tmp_path, rows)
    splits = verify_bundle(output)
    assert sum(map(len, splits.values())) == len(rows)
    manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
    assert len(manifest["dataset_id"]) > 20
    assert manifest["evaluation_scope"] == "contains_synthetic"
    seen_keys: set[str] = set()
    for members in splits.values():
        assert set(row["category"] for row in members) == set(
            Taxonomy.load(TAXONOMY).labels
        )
        keys = {description_key(row["text"]) for row in members}
        assert not seen_keys.intersection(keys)
        seen_keys.update(keys)
    assert (tmp_path / "original.csv").read_bytes() == original


def test_exact_duplicates_consolidate_and_conflicts_are_quarantined(
    tmp_path: Path,
) -> None:
    """Conflicting copies are quarantined regardless of which copy appears first."""
    rows = examples()
    duplicate = dict(rows[0])
    rows.append(duplicate)
    rows.extend(
        [
            {"text": "cùng một nội dung 10k", "category": "Ăn uống"},
            {"text": "CÙNG MỘT NỘI DUNG 10k", "category": "Đi lại"},
        ]
    )
    output = prepare(tmp_path, rows)
    audit = json.loads((output / "audit.json").read_text(encoding="utf-8"))
    assert audit["duplicates_removed"] == 1
    assert audit["review_reasons"]["conflicting_annotation"] == 2
    assert (
        audit["raw_rows"]
        == audit["eligible_unique_rows"]
        + audit["review_rows"]
        + audit["duplicates_removed"]
    )
    assert audit["duplicate_groups"][0]["occurrences"] == 2


def test_ambiguous_unknown_and_nonexpense_rows_require_review(tmp_path: Path) -> None:
    """Unknown purpose is distinct from Other, and transfer/income is outside scope."""
    rows = examples() + [
        {"text": "mua đồ 3tr5", "category": "Mua sắm"},
        {"text": "shope 30k", "category": "Mua sắm"},
        {"text": "grab 50k", "category": "Đi lại"},
        {"text": "nhận lương 15tr", "category": "Khác"},
        {"text": "chuyển từ ví tiền mặt 50k", "category": "Khác"},
        {"text": "nội dung có danh mục lạ", "category": "Invalid"},
        {"text": "", "category": "Khác"},
        {
            "text": "chuyển ngân hàng của tôi",
            "category": "Khác",
            "transaction_type": "transfer",
        },
    ]
    output = prepare(tmp_path, rows)
    audit = json.loads((output / "audit.json").read_text(encoding="utf-8"))
    assert audit["review_rows"] == 8
    assert audit["review_reasons"]["ambiguous_description"] == 3
    assert audit["review_reasons"]["possible_income_transfer_or_debt"] == 2
    assert audit["review_reasons"]["unknown_category"] == 1
    assert audit["review_reasons"]["outside_expense_taxonomy"] == 1


def test_real_rows_default_to_pending_and_fail_without_approved_groups(
    tmp_path: Path,
) -> None:
    """Real provenance never automatically grants human annotation approval."""
    path = write_input(tmp_path / "real.csv", examples())
    output = tmp_path / "prepared"
    with pytest.raises(ValueError, match="independent groups"):
        prepare_dataset(
            [Source(path, "real", "real", "owner-approved")],
            TAXONOMY,
            output,
            ambiguity_policy="quarantine",
        )
    assert not (output / "train.csv").exists()
    assert not (output / "manifest.json").exists()
    audit = json.loads((output / "audit.json").read_text(encoding="utf-8"))
    assert audit["status"] == "failed"
    assert audit["review_reasons"]["annotation_pending"] == len(examples())


def test_metadata_groups_and_transitive_near_duplicates_stay_together(
    tmp_path: Path,
) -> None:
    """Declared person/template groups and chains of close wording are transitive."""
    rows = examples()
    rows[0]["subject_id"] = "person_a"
    rows[20]["subject_id"] = "person_a"
    rows.extend(
        [
            {"text": "abcdefghij 10k", "category": "Ăn uống"},
            {"text": "abcdxfghij 20k", "category": "Ăn uống"},
            {"text": "abcdxfghiz 30k", "category": "Ăn uống"},
        ]
    )
    output = prepare(tmp_path, rows)
    splits = verify_bundle(output)
    memberships = {
        row["text"]: (split, row["group_id"])
        for split, members in splits.items()
        for row in members
    }
    assert memberships[rows[0]["text"]] == memberships[rows[20]["text"]]
    assert len({memberships[row["text"]] for row in rows[-3:]}) == 1


def test_split_membership_is_stable_under_input_shuffle(tmp_path: Path) -> None:
    """Seed, content and constraints determine membership rather than CSV row order."""
    left = tmp_path / "left"
    right = tmp_path / "right"
    left.mkdir()
    right.mkdir()
    rows = examples()
    first = verify_bundle(prepare(left, rows))
    random.Random(97).shuffle(rows)
    second = verify_bundle(prepare(right, rows))
    assert {
        split: [row["record_id"] for row in members] for split, members in first.items()
    } == {
        split: [row["record_id"] for row in members]
        for split, members in second.items()
    }


def test_nonempty_output_is_never_overwritten(tmp_path: Path) -> None:
    """A second run must use a new version instead of overwriting an old bundle."""
    output = prepare(tmp_path, examples())
    before = (output / "manifest.json").read_bytes()
    with pytest.raises(ValueError, match="not empty"):
        prepare(tmp_path, examples())
    assert (output / "manifest.json").read_bytes() == before


@pytest.mark.parametrize(
    "filename",
    [
        "train.csv",
        "validation.csv",
        "test.csv",
        "taxonomy.json",
        "audit.json",
        "review.csv",
        "annotation_template.csv",
    ],
)
def test_tampered_bundle_is_rejected(tmp_path: Path, filename: str) -> None:
    """Training must reject changed data, taxonomy, audit or review artifacts."""
    output = prepare(tmp_path, examples())
    with (output / filename).open("ab") as stream:
        stream.write(b"\n")
    with pytest.raises(ValueError, match="hash mismatch"):
        verify_bundle(output)


def test_structural_leakage_rejected_even_with_updated_file_hash(
    tmp_path: Path,
) -> None:
    """Hash checks are supplemented by actual group/ID overlap validation."""
    output = prepare(tmp_path, examples())
    splits = verify_bundle(output)
    train_group = splits["train"][0]["group_id"]
    path = output / "validation.csv"
    rows = splits["validation"]
    rows[0]["group_id"] = train_group
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    manifest_path = output / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["splits"]["validation"]["sha256"] = digest(path.read_bytes())
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(ValueError, match="cross-split leakage"):
        verify_bundle(output)


@pytest.mark.parametrize(
    "header,body",
    [
        ("text,label", "x,y"),
        ("text,text,category", "x,x,Khác"),
        ("text,category", "x,Khác,extra"),
        ("text,category,subject_id", "x,Khác"),
    ],
)
def test_malformed_csv_is_rejected(tmp_path: Path, header: str, body: str) -> None:
    """Bad schemas and column counts cannot silently alter labels or metadata."""
    path = tmp_path / "bad.csv"
    path.write_text(header + "\n" + body + "\n", encoding="utf-8")
    with pytest.raises(ValueError, match="invalid columns|malformed CSV"):
        read_sources([Source(path, "fixture", "synthetic", "test")])


def test_source_constraints_merge_across_duplicate_origins(tmp_path: Path) -> None:
    """Deduplication must preserve grouping constraints from every source copy."""
    path = write_input(
        tmp_path / "source.csv",
        [
            {"text": "cơm sườn 35k", "category": "Ăn uống", "subject_id": "a"},
            {"text": "cơm sườn 35k", "category": "Ăn uống", "subject_id": "b"},
            {"text": "đổ xăng 50k", "category": "Đi lại", "subject_id": "b"},
        ],
    )
    raw, _ = read_sources([Source(path, "fixture", "synthetic", "test")])
    records, _, _ = audit_records(raw, Taxonomy.load(TAXONOMY), "quarantine")
    group_records(records, 0.9)
    assert len(records) == 2
    assert len({row.group_id for row in records}) == 1


def test_insufficient_groups_and_invalid_ratios_are_actionable(tmp_path: Path) -> None:
    """Fail rather than splitting the same template to satisfy desired proportions."""
    path = write_input(tmp_path / "source.csv", examples())
    records, _ = read_sources([Source(path, "fixture", "synthetic", "test")])
    records, _, _ = audit_records(records, Taxonomy.load(TAXONOMY), "quarantine")
    group_records(records, 0.9)
    with pytest.raises(ValueError, match="sum to 1"):
        split_records(
            records, list(Taxonomy.load(TAXONOMY).labels), (0.8, 0.2, 0.2), 42
        )
    assert Counter(row.category for row in records)


def test_cli_verify_works_outside_repository(tmp_path: Path) -> None:
    """The standalone entry point uses portable paths and has no ML imports."""
    output = prepare(tmp_path, examples())
    result = subprocess.run(
        [
            sys.executable,
            str(ROOT / "backend/scripts/prepare_classifier_data.py"),
            "--verify",
            str(output),
        ],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["verified"] is True


def test_fewer_than_three_template_groups_cannot_be_split(tmp_path: Path) -> None:
    """Different amounts in one template do not count as independent groups."""
    rows = [
        {"text": f"cơm sườn {amount}k", "category": "Ăn uống"}
        for amount in range(10, 50)
    ]
    path = write_input(tmp_path / "source.csv", rows)
    output = tmp_path / "prepared"
    with pytest.raises(ValueError, match=">=3 independent groups"):
        prepare_dataset(
            [Source(path, "fixture", "synthetic", "test")],
            TAXONOMY,
            output,
            ambiguity_policy="quarantine",
        )
    assert (output / "audit.json").exists()
    assert not (output / "train.csv").exists()


def test_multi_source_cli_and_declared_source_groups(tmp_path: Path) -> None:
    """Relative source paths work and declared template constraints survive export."""
    rows = examples()
    rows[0]["template_id"] = "same_template"
    rows[10]["template_id"] = "same_template"
    write_input(tmp_path / "first.csv", rows)
    write_input(
        tmp_path / "second.csv",
        [
            {
                "text": "đặt khám chuyên khoa 90k",
                "category": "Y tế",
                "annotation_status": "approved",
            }
        ],
    )
    sources = tmp_path / "sources.json"
    sources.write_text(
        json.dumps(
            [
                {
                    "path": "first.csv",
                    "source_id": "first",
                    "kind": "synthetic",
                    "usage_rights": "test",
                },
                {
                    "path": "second.csv",
                    "source_id": "second",
                    "kind": "real",
                    "usage_rights": "owner consent",
                },
            ]
        ),
        encoding="utf-8",
    )
    output = tmp_path / "bundle"
    result = subprocess.run(
        [
            sys.executable,
            str(ROOT / "backend/scripts/prepare_classifier_data.py"),
            "--sources",
            str(sources),
            "--taxonomy",
            str(TAXONOMY),
            "--output-dir",
            str(output),
            "--ambiguity-policy",
            "quarantine",
        ],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    splits = verify_bundle(output)
    membership = {
        row["text"]: (split, row["group_id"])
        for split, members in splits.items()
        for row in members
    }
    assert membership[rows[0]["text"]] == membership[rows[10]["text"]]


def test_review_template_can_be_read_but_is_never_auto_approved(tmp_path: Path) -> None:
    """Review export uses supported input columns and remains pending on import."""
    output = prepare(
        tmp_path,
        examples()
        + [
            {
                "text": "grab 35k",
                "category": "Đi lại",
            }
        ],
    )
    source = Source(output / "annotation_template.csv", "reviewed", "synthetic", "test")
    records, _ = read_sources([source])
    assert len(records) == 1
    assert records[0].annotation_status == "pending"
    eligible, review, _ = audit_records(records, Taxonomy.load(TAXONOMY), "quarantine")
    assert not eligible
    assert "annotation_pending" in review[0].reasons


def test_template_identity_is_global_across_sources(tmp_path: Path) -> None:
    """Two collections of the same template cannot become independent groups."""
    first = write_input(
        tmp_path / "first.csv",
        [
            {
                "text": "cơm sườn 35k",
                "category": "Ăn uống",
                "template_id": "food.family_a",
            }
        ],
    )
    second = write_input(
        tmp_path / "second.csv",
        [
            {
                "text": "đặt bữa sáng ở công ty",
                "category": "Ăn uống",
                "template_id": "food.family_a",
            }
        ],
    )
    records, _ = read_sources(
        [
            Source(first, "first", "synthetic", "test"),
            Source(second, "second", "synthetic", "test"),
        ]
    )
    records, _, _ = audit_records(records, Taxonomy.load(TAXONOMY), "quarantine")
    group_records(records, 0.9)
    assert len({row.group_id for row in records}) == 1
