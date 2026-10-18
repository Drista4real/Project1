"""Prepare versioned classifier datasets without loading ML models or training.

Only the Python standard library is required. Exact duplicates are consolidated;
similar descriptions and declared provenance groups stay in a single split.
"""

from __future__ import annotations

import csv
import hashlib
import io
import json
import math
import random
import re
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any

SPLITS = ("train", "validation", "test")
SOURCE_KINDS = {"synthetic", "real", "public"}
STATUSES = {"approved", "pending", "rejected", "synthetic", "provided"}
OPTIONAL_COLUMNS = {
    "record_id",
    "transaction_type",
    "annotation_status",
    "source_group",
    "subject_id",
    "template_id",
    "review_reasons",
    "annotator_id",
    "annotation_note",
}
OUTPUT_COLUMNS = (
    "record_id",
    "text",
    "category",
    "category_id",
    "transaction_type",
    "annotation_status",
    "source_group",
    "subject_id",
    "template_id",
    "review_reasons",
    "group_id",
    "origins",
)
MONEY = re.compile(
    r"\d+(?:[.,]\d+)*(?:\s*(?:trieu|nghin|ngan|dong|canh|cu|xi|tr|k|d))?"
    r"(?:\s*\d+)?(?:\s*ruoi)?\b"
)


def digest(value: str | bytes) -> str:
    """Return SHA256 for UTF-8 text or bytes."""
    return hashlib.sha256(
        value.encode("utf-8") if isinstance(value, str) else value
    ).hexdigest()


def exact_key(text: str) -> str:
    """Normalize case, NFC and whitespace while preserving accents and amounts."""
    return " ".join(unicodedata.normalize("NFC", text).casefold().split())


def description_key(text: str) -> str:
    """Mask numeric money and punctuation for conservative leakage grouping.

    This key is NOT model preprocessing and never replaces the original text.
    Masking can over-group descriptions; it must never be used to infer labels.
    """
    text = exact_key(text).replace("đ", "d")
    text = "".join(
        char
        for char in unicodedata.normalize("NFD", text)
        if unicodedata.category(char) != "Mn"
    )
    text = MONEY.sub(" ", text)
    return " ".join(re.findall(r"[a-z]+", text))


def write_json(path: Path, payload: Any) -> None:
    """Write a readable UTF-8 JSON artifact with deterministic key ordering."""
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


@dataclass(frozen=True)
class Taxonomy:
    """Load stable category identifiers without depending on six-class inference."""

    version: str
    labels: dict[str, str]
    ambiguity_keys: frozenset[str]
    outside_scope_patterns: tuple[str, ...]
    sha256: str
    approved_scope_exceptions: frozenset[tuple[str, str]] = frozenset()

    @classmethod
    def load(cls, path: Path) -> Taxonomy:
        """Validate the taxonomy contract before accepting any dataset labels."""
        raw = path.read_bytes()
        payload = json.loads(raw)
        if payload.get("schema_version") != 1 or not payload.get("version"):
            raise ValueError("Taxonomy requires schema_version=1 and a version")
        entries = payload.get("categories", [])
        labels = {entry["name"]: entry["id"] for entry in entries}
        if (
            not labels
            or len(labels) != len(entries)
            or len(set(labels.values())) != len(labels)
            or any(not isinstance(k, str) or not k.strip() for k in labels)
            or any(
                not isinstance(v, str) or not re.fullmatch(r"[a-z][a-z_]*", v)
                for v in labels.values()
            )
        ):
            raise ValueError("Taxonomy needs unique nonempty names and stable IDs")
        if payload.get("transaction_type") != "expense":
            raise ValueError("This taxonomy must explicitly describe expenses")
        patterns = tuple(payload.get("outside_scope_patterns", []))
        for pattern in patterns:
            re.compile(pattern)
        exceptions = payload.get("approved_scope_exceptions", [])
        if any(
            entry.get("category") not in labels
            or not entry.get("text", "").strip()
            or entry.get("approved_by") != "user"
            or not entry.get("decision_date")
            or not entry.get("note")
            for entry in exceptions
        ):
            raise ValueError(
                "Scope exceptions require exact text/category and user decision"
            )
        return cls(
            payload["version"],
            labels,
            frozenset(
                description_key(text) for text in payload.get("ambiguous_examples", [])
            ),
            patterns,
            digest(raw),
            frozenset((exact_key(e["text"]), e["category"]) for e in exceptions),
        )


@dataclass(frozen=True)
class Source:
    """An explicitly declared input source; provenance is never guessed."""

    path: Path
    source_id: str
    kind: str
    license: str

    def __post_init__(self) -> None:
        """Require an identifier, declared origin and rights statement."""
        if not self.source_id.strip() or self.kind not in SOURCE_KINDS:
            raise ValueError(
                "Source needs a nonempty ID and synthetic/real/public kind"
            )
        if not self.license.strip():
            raise ValueError("Declare the source license or usage-rights statement")


@dataclass
class Record:
    """A canonical example retaining all source occurrences after deduplication."""

    record_id: str
    text: str
    category: str
    transaction_type: str
    annotation_status: str
    origins: list[dict[str, Any]]
    constraints: set[str] = field(default_factory=set)
    reasons: set[str] = field(default_factory=set)
    source_group: str = ""
    subject_id: str = ""
    template_id: str = ""
    group_id: str = ""

    def as_row(self, taxonomy: Taxonomy) -> dict[str, str]:
        """Serialize an example without losing provenance or review flags."""
        return {
            "record_id": self.record_id,
            "text": self.text,
            "category": self.category,
            "category_id": taxonomy.labels.get(self.category, ""),
            "transaction_type": self.transaction_type,
            "annotation_status": self.annotation_status,
            "source_group": self.source_group,
            "subject_id": self.subject_id,
            "template_id": self.template_id,
            "review_reasons": "|".join(sorted(self.reasons)),
            "group_id": self.group_id,
            "origins": json.dumps(self.origins, ensure_ascii=False, sort_keys=True),
        }


def read_sources(sources: list[Source]) -> tuple[list[Record], list[dict[str, Any]]]:
    """Read strict CSV schemas and preserve original rows, hashes and source IDs."""
    if not sources or len({source.source_id for source in sources}) != len(sources):
        raise ValueError("At least one source is required; source IDs must be unique")
    records: list[Record] = []
    manifests: list[dict[str, Any]] = []
    supplied_ids: dict[tuple[str, str], tuple[str, str]] = {}
    for source in sorted(sources, key=lambda item: item.source_id):
        raw = source.path.read_bytes()
        reader = csv.DictReader(
            io.StringIO(raw.decode("utf-8-sig"), newline=""), strict=True
        )
        columns = reader.fieldnames or []
        if (
            len(columns) != len(set(columns))
            or not {"text", "category"}.issubset(columns)
            or set(columns) - {"text", "category"} - OPTIONAL_COLUMNS
        ):
            raise ValueError(
                f"{source.source_id}: invalid columns; require text,category"
            )
        count = 0
        for line, row in enumerate(reader, start=2):
            if None in row or any(value is None for value in row.values()):
                raise ValueError(f"{source.source_id}: malformed CSV record {line}")
            count += 1
            text = unicodedata.normalize("NFC", row["text"]).strip()
            category = unicodedata.normalize("NFC", row["category"]).strip()
            record_id = "rec_" + digest(exact_key(text))[:24]
            original_id = row.get("record_id", "").strip()
            if original_id:
                identity = (source.source_id, original_id)
                content = (exact_key(text), category)
                if identity in supplied_ids and supplied_ids[identity] != content:
                    raise ValueError(
                        f"{source.source_id}: record_id reused with different content"
                    )
                supplied_ids[identity] = content
            status = row.get("annotation_status", "").strip() or (
                "synthetic" if source.kind == "synthetic" else "pending"
            )
            record = Record(
                record_id,
                text,
                category,
                row.get("transaction_type", "").strip() or "expense",
                status,
                [
                    {
                        "source_id": source.source_id,
                        "source_kind": source.kind,
                        "row": line,
                        "original_record_id": original_id,
                        "source_group": row.get("source_group", "").strip(),
                        "subject_id": row.get("subject_id", "").strip(),
                        "template_id": row.get("template_id", "").strip(),
                        "annotation_status": status,
                        "annotator_id": row.get("annotator_id", "").strip(),
                        "annotation_note": row.get("annotation_note", "").strip(),
                        "review_reasons": row.get("review_reasons", "").strip(),
                    }
                ],
                source_group=row.get("source_group", "").strip(),
                subject_id=row.get("subject_id", "").strip(),
                template_id=row.get("template_id", "").strip(),
            )
            if record.source_group:
                record.constraints.add(
                    f"{source.source_id}:source_group:{record.source_group}"
                )
            if record.template_id:
                record.constraints.add(f"template:{record.template_id}")
            if record.subject_id:
                # Pseudonymous subject IDs must be consistent across input sources.
                record.constraints.add(f"subject:{record.subject_id}")
            if row.get("review_reasons", "").strip():
                record.reasons.add("annotator_flag")
            if status not in STATUSES:
                record.reasons.add("invalid_annotation_status")
            if source.kind != "synthetic" and status == "synthetic":
                record.reasons.add("invalid_synthetic_provenance")
            records.append(record)
        if count == 0:
            raise ValueError(f"{source.source_id}: empty dataset")
        manifests.append(
            {
                "source_id": source.source_id,
                "kind": source.kind,
                "filename": source.path.name,
                "sha256": digest(raw),
                "rows": count,
                "usage_rights": source.license,
            }
        )
    return records, manifests


def audit_records(
    records: list[Record],
    taxonomy: Taxonomy,
    ambiguity_policy: str,
) -> tuple[list[Record], list[Record], dict[str, Any]]:
    """Quarantine invalid/conflicting examples and consolidate exact duplicates."""
    if ambiguity_policy not in {"quarantine", "keep_flagged"}:
        raise ValueError("Ambiguity policy must be quarantine or keep_flagged")
    by_text: dict[str, list[Record]] = defaultdict(list)
    for record in records:
        if not record.text:
            record.reasons.add("empty_text")
        if len(record.text) > 2000:
            record.reasons.add("text_too_long")
        if record.category not in taxonomy.labels:
            record.reasons.add("unknown_category")
        if record.transaction_type != "expense":
            record.reasons.add("outside_expense_taxonomy")
        if record.annotation_status in {"pending", "rejected"}:
            record.reasons.add("annotation_" + record.annotation_status)
        if not description_key(record.text):
            record.reasons.add("no_description")
        if description_key(record.text) in taxonomy.ambiguity_keys:
            record.reasons.add("ambiguous_description")
        if (
            exact_key(record.text),
            record.category,
        ) not in taxonomy.approved_scope_exceptions and any(
            re.search(pattern, description_key(record.text))
            for pattern in taxonomy.outside_scope_patterns
        ):
            record.reasons.add("possible_income_transfer_or_debt")
        by_text[exact_key(record.text)].append(record)
    eligible: list[Record] = []
    review: list[Record] = []
    duplicate_groups: list[dict[str, Any]] = []
    duplicates_removed = 0
    raw_duplicate_excess = sum(len(members) - 1 for members in by_text.values())
    for key in sorted(by_text):
        members = by_text[key]
        signatures = {(row.category, row.transaction_type) for row in members}
        if len(signatures) > 1:
            for record in members:
                record.reasons.add("conflicting_annotation")
        # A review flag on any exact duplicate cannot be bypassed by another copy.
        reasons = set().union(*(record.reasons for record in members))
        blocking = reasons - (
            {"ambiguous_description"} if ambiguity_policy == "keep_flagged" else set()
        )
        if blocking:
            for record in members:
                record.reasons.update(reasons)
                review.append(record)
            continue
        members.sort(
            key=lambda row: (
                row.text,
                row.origins[0]["source_id"],
                row.origins[0]["row"],
            )
        )
        canonical = members[0]
        canonical.reasons = reasons
        canonical.origins = sorted(
            [origin for record in members for origin in record.origins],
            key=lambda origin: (origin["source_id"], origin["row"]),
        )
        canonical.constraints = set().union(*(record.constraints for record in members))
        if len(members) > 1:
            duplicates_removed += len(members) - 1
            duplicate_groups.append(
                {
                    "record_id": canonical.record_id,
                    "occurrences": len(members),
                    "origins": canonical.origins,
                }
            )
        eligible.append(canonical)
    return (
        eligible,
        review,
        {
            "raw_rows": len(records),
            "raw_exact_duplicate_excess": raw_duplicate_excess,
            "eligible_unique_rows": len(eligible),
            "review_rows": len(review),
            "duplicates_removed": duplicates_removed,
            "duplicate_groups": duplicate_groups,
            "review_reasons": dict(
                sorted(
                    Counter(
                        reason for record in review for reason in record.reasons
                    ).items()
                )
            ),
            "review_rules_are_exhaustive": False,
            "metadata_coverage": {
                "rows_with_subject_id": sum(bool(row.subject_id) for row in records),
                "rows_with_template_id": sum(bool(row.template_id) for row in records),
                "rows_with_source_group": sum(
                    bool(row.source_group) for row in records
                ),
            },
        },
    )


class Components:
    """Compute transitive groups, including chains of similar descriptions."""

    def __init__(self, size: int) -> None:
        """Start with one independent component per canonical example."""
        self.parents = list(range(size))

    def root(self, index: int) -> int:
        """Find the representative with path compression."""
        while index != self.parents[index]:
            self.parents[index] = self.parents[self.parents[index]]
            index = self.parents[index]
        return index

    def join(self, left: int, right: int) -> None:
        """Merge two groups without depending on the caller's row order."""
        left, right = self.root(left), self.root(right)
        self.parents[max(left, right)] = min(left, right)


def group_records(
    records: list[Record], threshold: float, max_near_comparisons: int = 2_000_000
) -> dict[str, Any]:
    """Keep masked amounts, near descriptions and provenance in atomic groups.

    Near matching uses a trigram candidate index and a bounded comparison budget.
    It fails explicitly on excessive candidates instead of silently skipping them.
    """
    if not math.isfinite(threshold) or not 0.8 <= threshold <= 1.0:
        raise ValueError("Near-duplicate threshold must be between 0.8 and 1")
    records.sort(key=lambda record: record.record_id)
    components = Components(len(records))
    keys: dict[str, int] = {}
    skeletons: dict[str, int] = {}
    for index, record in enumerate(records):
        skeleton = description_key(record.text).replace(" ", "")
        for key in sorted(record.constraints | {"description:" + skeleton}):
            if key in keys:
                components.join(index, keys[key])
            else:
                keys[key] = index
        skeletons.setdefault(skeleton, index)
    inverted: dict[str, set[str]] = defaultdict(set)
    short_keys = [key for key in skeletons if len(key) <= 8]
    near_pairs: list[dict[str, Any]] = []
    comparisons = 0
    for skeleton in sorted(skeletons):
        grams = {skeleton[i : i + 3] for i in range(max(0, len(skeleton) - 2))}
        candidates = set().union(*(inverted[gram] for gram in grams))
        # Short descriptions may have no common trigram despite high similarity.
        candidates.update(key for key in short_keys if key < skeleton)
        for other in sorted(candidates):
            if (
                2 * min(len(skeleton), len(other)) / (len(skeleton) + len(other))
                < threshold
            ):
                continue
            comparisons += 1
            if comparisons > max_near_comparisons:
                raise ValueError(
                    "Near-duplicate budget exceeded; curate source groups first"
                )
            matcher = SequenceMatcher(None, skeleton, other, autojunk=False)
            if matcher.quick_ratio() < threshold:
                continue
            similarity = matcher.ratio()
            if similarity >= threshold:
                left, right = skeletons[skeleton], skeletons[other]
                components.join(left, right)
                near_pairs.append(
                    {
                        "left": records[left].record_id,
                        "right": records[right].record_id,
                        "similarity": round(similarity, 6),
                    }
                )
        for gram in grams:
            inverted[gram].add(skeleton)
    groups: dict[int, list[Record]] = defaultdict(list)
    for index, record in enumerate(records):
        groups[components.root(index)].append(record)
    for members in groups.values():
        group_id = (
            "grp_" + digest("\n".join(sorted(row.record_id for row in members)))[:24]
        )
        for record in members:
            record.group_id = group_id
    return {
        "algorithm": "nfc_exact_money_mask_accentfold_compact_sequence_v1",
        "near_threshold": threshold,
        "near_candidate_comparisons": comparisons,
        "near_pairs": near_pairs,
        "groups": len(groups),
        "largest_group_rows": max((len(group) for group in groups.values()), default=0),
        "groups_per_category": {
            category: len(
                {record.group_id for record in records if record.category == category}
            )
            for category in sorted({record.category for record in records})
        },
        "limitations": [
            "Lexical matching cannot prove semantic independence or label correctness.",
            "Money masking can conservatively group unrelated numeric descriptions.",
            "User/source/template isolation only applies when metadata is supplied.",
        ],
    }


def split_records(
    records: list[Record],
    labels: list[str],
    ratios: tuple[float, float, float],
    seed: int,
) -> dict[str, list[Record]]:
    """Assign whole groups with approximate label balance and class coverage."""
    if (
        len(ratios) != 3
        or any(not math.isfinite(r) or r <= 0 for r in ratios)
        or not math.isclose(sum(ratios), 1.0, abs_tol=1e-9)
    ):
        raise ValueError("Three positive split ratios must sum to 1")
    groups: dict[str, list[Record]] = defaultdict(list)
    for record in records:
        groups[record.group_id].append(record)
    support = {
        label: sum(
            any(row.category == label for row in group) for group in groups.values()
        )
        for label in labels
    }
    insufficient = {label: count for label, count in support.items() if count < 3}
    if insufficient:
        raise ValueError(f"Need >=3 independent groups per category: {insufficient}")
    totals = Counter(record.category for record in records)
    vectors = {
        key: Counter(row.category for row in group) for key, group in groups.items()
    }
    counts: dict[str, Counter[str]] = {split: Counter() for split in SPLITS}
    assigned: dict[str, str] = {}
    rng = random.Random(seed)
    tie = {key: rng.random() for key in sorted(groups)}

    def cost(group_id: str, split: str) -> float:
        """Measure normalized squared-error increase against per-label targets."""
        ratio = ratios[SPLITS.index(split)]
        return sum(
            (
                (counts[split][label] + value - totals[label] * ratio) ** 2
                - (counts[split][label] - totals[label] * ratio) ** 2
            )
            / max(1.0, totals[label] * ratio)
            for label, value in vectors[group_id].items()
        )

    def assign(group_id: str, split: str) -> None:
        """Record an atomic assignment and its complete label vector."""
        assigned[group_id] = split
        counts[split].update(vectors[group_id])

    # Seed every label into all splits before optimizing the remaining groups.
    for label in sorted(labels, key=lambda name: (support[name], name)):
        for split in SPLITS:
            if counts[split][label]:
                continue
            candidates = [
                key for key in groups if key not in assigned and vectors[key][label]
            ]
            if not candidates:
                raise ValueError(
                    "Cannot preserve class coverage; curate more independent groups"
                )
            chosen = min(candidates, key=lambda key: (cost(key, split), tie[key], key))
            assign(chosen, split)
    for key in sorted(groups, key=lambda key: (-len(groups[key]), tie[key], key)):
        if key not in assigned:
            assign(
                key,
                min(SPLITS, key=lambda split: (cost(key, split), SPLITS.index(split))),
            )
    result = {split: [] for split in SPLITS}
    for group_id, split in assigned.items():
        result[split].extend(groups[group_id])
    for split in SPLITS:
        result[split].sort(key=lambda record: record.record_id)
        if set(counts[split]) != set(labels):
            raise ValueError(f"Missing class coverage in {split}")
    return result


def write_csv(path: Path, records: list[Record], taxonomy: Taxonomy) -> None:
    """Write UTF-8 rows safely, preserving exact text and machine-readable IDs."""
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=OUTPUT_COLUMNS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(record.as_row(taxonomy) for record in records)


def write_annotation_template(path: Path, records: list[Record]) -> None:
    """Export editable supported columns, initially pending instead of approved."""
    columns = (
        "record_id",
        "text",
        "category",
        "transaction_type",
        "annotation_status",
        "source_group",
        "subject_id",
        "template_id",
        "review_reasons",
        "annotator_id",
        "annotation_note",
    )
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns, lineterminator="\n")
        writer.writeheader()
        for record in records:
            # Expand origins so none of the original split constraints are lost.
            for origin in record.origins:
                writer.writerow(
                    {
                        "record_id": record.record_id,
                        "text": record.text,
                        "category": record.category,
                        "transaction_type": record.transaction_type,
                        "annotation_status": "pending",
                        "source_group": origin["source_group"],
                        "subject_id": origin["subject_id"],
                        "template_id": origin["template_id"],
                        "review_reasons": "|".join(sorted(record.reasons)),
                        "annotator_id": "",
                        "annotation_note": "",
                    }
                )


def verify_bundle(path: Path) -> dict[str, list[dict[str, str]]]:
    """Verify file hashes, record IDs, schema and no group leakage before training."""
    manifest = json.loads((path / "manifest.json").read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1:
        raise ValueError("Unsupported prepared dataset manifest")
    taxonomy_path = path / "taxonomy.json"
    if digest(taxonomy_path.read_bytes()) != manifest["taxonomy"]["sha256"]:
        raise ValueError("Taxonomy hash mismatch")
    taxonomy = Taxonomy.load(taxonomy_path)
    for filename, hash_key in (
        ("audit.json", "audit_sha256"),
        ("review.csv", "review_sha256"),
        ("annotation_template.csv", "annotation_template_sha256"),
    ):
        if digest((path / filename).read_bytes()) != manifest[hash_key]:
            raise ValueError(f"{filename} hash mismatch")
    result: dict[str, list[dict[str, str]]] = {}
    seen_ids: set[str] = set()
    seen_groups: set[str] = set()
    seen_texts: set[str] = set()
    for split in SPLITS:
        raw = (path / f"{split}.csv").read_bytes()
        info = manifest["splits"][split]
        if digest(raw) != info["sha256"]:
            raise ValueError(f"{split} hash mismatch")
        reader = csv.DictReader(io.StringIO(raw.decode("utf-8"), newline=""))
        if reader.fieldnames != list(OUTPUT_COLUMNS):
            raise ValueError(f"{split}: unexpected columns")
        rows = list(reader)
        ids = [row["record_id"] for row in rows]
        groups = {row["group_id"] for row in rows}
        texts = {exact_key(row["text"]) for row in rows}
        if (
            len(rows) != info["rows"]
            or len(ids) != len(set(ids))
            or ids != info["record_ids"]
            or sorted(groups) != info["group_ids"]
            or len(groups) != info["groups"]
            or seen_ids.intersection(ids)
            or seen_groups.intersection(groups)
            or seen_texts.intersection(texts)
            or "" in groups
            or Counter(row["category"] for row in rows) != info["category_counts"]
            or set(row["category"] for row in rows) != set(taxonomy.labels)
            or any(
                row["category_id"] != taxonomy.labels.get(row["category"])
                or row["transaction_type"] != "expense"
                or row["record_id"] != "rec_" + digest(exact_key(row["text"]))[:24]
                for row in rows
            )
        ):
            raise ValueError(
                f"{split}: invalid records, class coverage or cross-split leakage"
            )
        seen_ids.update(ids)
        seen_groups.update(groups)
        seen_texts.update(texts)
        result[split] = rows
    return result


def prepare_dataset(
    sources: list[Source],
    taxonomy_path: Path,
    output_dir: Path,
    *,
    ambiguity_policy: str,
    ratios: tuple[float, float, float] = (0.7, 0.15, 0.15),
    seed: int = 42,
    near_threshold: float = 0.9,
    max_near_comparisons: int = 2_000_000,
) -> dict[str, Any]:
    """Audit and export a new immutable bundle; never change source CSV/checkpoints.

    Validation failures retain review/audit files but no train/validation/test files.
    Existing nonempty output directories are refused rather than overwritten.
    """
    if output_dir.exists() and any(output_dir.iterdir()):
        raise ValueError("Output directory is not empty; choose a new dataset version")
    taxonomy = Taxonomy.load(taxonomy_path)
    raw, source_manifest = read_sources(sources)
    records, review, audit = audit_records(raw, taxonomy, ambiguity_policy)
    grouping = group_records(records, near_threshold, max_near_comparisons)
    audit["grouping"] = grouping
    audit["ambiguity_policy"] = ambiguity_policy
    audit["eligible_category_counts"] = dict(
        sorted(Counter(row.category for row in records).items())
    )
    audit["warnings"] = [
        "Synthetic splits are development benchmarks, not real-world evaluation.",
        "Heuristic ambiguity checks do not replace human annotation review.",
        "Review reports may contain sensitive text; keep this bundle private.",
    ]
    output_dir.mkdir(parents=True, exist_ok=True)
    write_csv(output_dir / "review.csv", review, taxonomy)
    write_annotation_template(output_dir / "annotation_template.csv", review)
    try:
        splits = split_records(records, list(taxonomy.labels), ratios, seed)
    except ValueError as error:
        audit["status"] = "failed"
        audit["failure"] = str(error)
        write_json(output_dir / "audit.json", audit)
        raise
    taxonomy_raw = taxonomy_path.read_bytes()
    (output_dir / "taxonomy.json").write_bytes(taxonomy_raw)
    manifest: dict[str, Any] = {
        "schema_version": 1,
        "taxonomy": {"version": taxonomy.version, "sha256": taxonomy.sha256},
        "sources": source_manifest,
        "pipeline": {
            "version": "classifier_dataset_v1",
            "sha256": digest(Path(__file__).read_bytes()),
            "seed": seed,
            "target_ratios": dict(zip(SPLITS, ratios, strict=True)),
            "near_threshold": near_threshold,
            "max_near_comparisons": max_near_comparisons,
            "ambiguity_policy": ambiguity_policy,
        },
        "splits": {},
        "evaluation_scope": "contains_synthetic"
        if any(source.kind == "synthetic" for source in sources)
        else "declared_sources_only_not_quality_certified",
    }
    for split, members in splits.items():
        filename = f"{split}.csv"
        write_csv(output_dir / filename, members, taxonomy)
        manifest["splits"][split] = {
            "rows": len(members),
            "groups": len({row.group_id for row in members}),
            "actual_ratio": len(members) / len(records),
            "category_counts": dict(
                sorted(Counter(row.category for row in members).items())
            ),
            "record_ids": [row.record_id for row in members],
            "group_ids": sorted({row.group_id for row in members}),
            "sha256": digest((output_dir / filename).read_bytes()),
        }
    fingerprint = {
        "taxonomy": taxonomy.sha256,
        "sources": source_manifest,
        "pipeline": manifest["pipeline"],
        "split_hashes": {
            key: value["sha256"] for key, value in manifest["splits"].items()
        },
    }
    manifest["dataset_id"] = (
        "dataset_" + digest(json.dumps(fingerprint, sort_keys=True))[:24]
    )
    audit["status"] = "passed"
    write_json(output_dir / "audit.json", audit)
    manifest["audit_sha256"] = digest((output_dir / "audit.json").read_bytes())
    manifest["review_sha256"] = digest((output_dir / "review.csv").read_bytes())
    manifest["annotation_template_sha256"] = digest(
        (output_dir / "annotation_template.csv").read_bytes()
    )
    write_json(output_dir / "manifest.json", manifest)
    verify_bundle(output_dir)
    return manifest
