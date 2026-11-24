"""Compare every function in schema `public` between two databases.

The reference is a throwaway PostgreSQL built from schema.sql plus every
migration (the e2e `migrate` stack). The target is the database to check,
usually the live project. Bodies are compared by md5(prosrc), so no SQL file
is parsed. Connection strings are never printed.

    python -m scripts.check_function_drift --reference-url <url>
    python -m scripts.check_function_drift --reference-url <url> --database-url <url>

`--database-url` falls back to DATABASE_URL in backend/.env, as in
apply_migrations.py. The exit code is 1 on any difference.
"""

import argparse
import sys
from collections.abc import Sequence
from dataclasses import dataclass, fields
from pathlib import Path

if str(Path(__file__).resolve().parents[1]) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.apply_migrations import _database_url, _placeholder_password  # noqa: E402

# Functions owned by an extension come from the platform, not the migrations.
FUNCTIONS_SQL = """
SELECT p.oid::regprocedure::text,
       md5(p.prosrc),
       length(p.prosrc),
       p.prosecdef,
       p.proconfig,
       has_function_privilege('anon', p.oid, 'EXECUTE'),
       has_function_privilege('authenticated', p.oid, 'EXECUTE'),
       has_function_privilege('service_role', p.oid, 'EXECUTE')
  FROM pg_catalog.pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace
   AND NOT EXISTS (
     SELECT 1 FROM pg_catalog.pg_depend d
      WHERE d.classid = 'pg_catalog.pg_proc'::regclass
        AND d.objid = p.oid
        AND d.deptype = 'e'
   )
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
                differences.append(
                    f"{signature}: {field.name} reference={before!r} target={after!r}"
                )
    return differences


def _fetch(url: str, label: str) -> list[FunctionRow]:
    """Read the public functions of one database.

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
    except Exception as error:  # noqa: BLE001 - reported without its message
        raise SystemExit(
            f"Could not read functions from the {label} database "
            f"({type(error).__name__})."
        ) from None
    return [
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

    reference = _fetch(args.reference_url, "reference")
    target = _fetch(target_url, "target")
    differences = compare_functions(reference, target)

    for row in target:
        flagged = any(
            line.startswith(f"{row.signature}: ") or line.endswith(f": {row.signature}")
            for line in differences
        )
        status = "DIFFERS" if flagged else "ok"
        print(f"{status:8} {row.body_md5[:6]} {row.body_length:6} {row.signature}")
    print(f"{len(target)} public functions in target, {len(reference)} in reference")
    for line in differences:
        print(f"- {line}")
    if differences:
        raise SystemExit(f"{len(differences)} difference(s) found.")
    print("No difference.")


if __name__ == "__main__":
    main()
