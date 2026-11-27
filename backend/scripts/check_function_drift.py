"""Compare every public function not owned by an extension between two databases.

The reference is a throwaway PostgreSQL built from schema.sql plus every
migration (the e2e `migrate` stack). The target is the database to check,
usually the live project. Functions an extension owns come from the platform,
not the migrations, so they are skipped and only counted. Bodies are compared
by md5(prosrc), so no SQL file is parsed. Connection strings and function
setting values other than search_path are never printed.

    python -m scripts.check_function_drift --reference-url <url>
    python -m scripts.check_function_drift --reference-url <url> --database-url <url>

`--database-url` falls back to DATABASE_URL in backend/.env, as in
apply_migrations.py. The exit code is 1 on any difference.
"""

import argparse
import hashlib
import sys
from collections.abc import Sequence
from dataclasses import dataclass, fields
from pathlib import Path

if str(Path(__file__).resolve().parents[1]) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.apply_migrations import _database_url, _placeholder_password  # noqa: E402

PUBLIC_FUNCTION = "p.pronamespace = 'public'::regnamespace"
EXTENSION_OWNED = """EXISTS (
     SELECT 1 FROM pg_catalog.pg_depend d
      WHERE d.classid = 'pg_catalog.pg_proc'::regclass
        AND d.objid = p.oid
        AND d.deptype = 'e'
   )"""
EXTENSION_FUNCTIONS_SQL = f"""
SELECT count(*) FROM pg_catalog.pg_proc p
 WHERE {PUBLIC_FUNCTION} AND {EXTENSION_OWNED}
"""
FUNCTIONS_SQL = f"""
SELECT p.oid::regprocedure::text,
       md5(p.prosrc),
       length(p.prosrc),
       p.prosecdef,
       p.proconfig,
       has_function_privilege('anon', p.oid, 'EXECUTE'),
       has_function_privilege('authenticated', p.oid, 'EXECUTE'),
       has_function_privilege('service_role', p.oid, 'EXECUTE')
  FROM pg_catalog.pg_proc p
 WHERE {PUBLIC_FUNCTION} AND NOT {EXTENSION_OWNED}
 ORDER BY 1
"""


@dataclass(frozen=True)
class FunctionRow:
    """One function as the catalog describes it."""

    signature: str
    body_md5: str
    body_length: int
    security_definer: bool
    config: tuple[str, ...] | None
    anon_execute: bool
    authenticated_execute: bool
    service_role_execute: bool


def compare_functions(
    reference: Sequence[FunctionRow], target: Sequence[FunctionRow]
) -> list[str]:
    """Describe every way the target differs from the reference.

    An empty list means both catalogs agree on every compared field.
    """
    wanted = {row.signature: row for row in reference}
    found = {row.signature: row for row in target}
    differences: list[str] = []
    for signature in sorted(wanted.keys() | found.keys()):
        if signature not in found:
            differences.append(f"missing in target: {signature}")
            continue
        if signature not in wanted:
            differences.append(f"extra in target: {signature}")
            continue
        expected, actual = wanted[signature], found[signature]
        if (expected.body_md5, expected.body_length) != (
            actual.body_md5,
            actual.body_length,
        ):
            differences.append(
                f"{signature}: body reference={expected.body_md5} "
                f"({expected.body_length} chars) target={actual.body_md5} "
                f"({actual.body_length} chars)"
            )
        for field in fields(FunctionRow)[3:]:
            before = getattr(expected, field.name)
            after = getattr(actual, field.name)
            if before != after:
                if field.name == "config":
                    before, after = _redact(before), _redact(after)
                differences.append(
                    f"{signature}: {field.name} reference={before!r} target={after!r}"
                )
    return differences


def _redact(config: tuple[str, ...] | None) -> tuple[str, ...] | None:
    """Hide every setting value except search_path, which diagnosis needs.

    A setting can hold a credential, so the report shows its key and the
    first 8 hex characters of the sha256 of its value.
    """
    if config is None:
        return None
    shown: list[str] = []
    for setting in config:
        key, _, value = setting.partition("=")
        if key == "search_path":
            shown.append(setting)
        else:
            digest = hashlib.sha256(value.encode()).hexdigest()[:8]
            shown.append(f"{key}=sha256:{digest}")
    return tuple(shown)


def _fetch(url: str, label: str) -> tuple[list[FunctionRow], int]:
    """Read the compared functions of one database and count the skipped ones.

    Errors name the database by label and exception type only: a driver
    message can quote the connection string.
    """
    if _placeholder_password(url):
        raise SystemExit(f"The {label} connection string holds a template password.")
    try:
        import psycopg
    except ImportError as error:
        raise SystemExit(
            'psycopg is not installed. Run: pip install "psycopg[binary]"'
        ) from error
    try:
        with psycopg.connect(url, connect_timeout=15) as connection:
            rows = connection.execute(FUNCTIONS_SQL).fetchall()
            skipped = connection.execute(EXTENSION_FUNCTIONS_SQL).fetchone()[0]
    except Exception as error:  # noqa: BLE001 - reported without its message
        raise SystemExit(
            f"Could not read functions from the {label} database "
            f"({type(error).__name__})."
        ) from None
    functions = [
        FunctionRow(
            signature=row[0],
            body_md5=row[1],
            body_length=row[2],
            security_definer=row[3],
            config=tuple(row[4]) if row[4] is not None else None,
            anon_execute=row[5],
            authenticated_execute=row[6],
            service_role_execute=row[7],
        )
        for row in rows
    ]
    return functions, skipped


def main() -> None:
    """Compare the two databases and exit non-zero on any difference."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reference-url",
        required=True,
        help="Database built from schema.sql and every migration",
    )
    parser.add_argument("--database-url", help="Database to check")
    args = parser.parse_args()

    target_url = _database_url(args.database_url)
    if not target_url:
        raise SystemExit("No DATABASE_URL found. Pass --database-url or set it.")

    reference, reference_skipped = _fetch(args.reference_url, "reference")
    target, target_skipped = _fetch(target_url, "target")
    differences = compare_functions(reference, target)

    for row in target:
        flagged = any(
            line.startswith(f"{row.signature}: ") or line.endswith(f": {row.signature}")
            for line in differences
        )
        status = "DIFFERS" if flagged else "ok"
        print(f"{status:8} {row.body_md5[:6]} {row.body_length:6} {row.signature}")
    print(f"{len(target)} public functions in target, {len(reference)} in reference")
    print(
        f"Skipped as owned by an extension: {target_skipped} in target, "
        f"{reference_skipped} in reference"
    )
    for line in differences:
        print(f"- {line}")
    if differences:
        raise SystemExit(f"{len(differences)} difference(s) found.")
    print("No difference.")


if __name__ == "__main__":
    main()
