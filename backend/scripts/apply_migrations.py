"""Apply the SQL migrations to a Supabase project over a direct connection.

The Supabase SQL editor works too, but this script applies a whole file and
reports what it found, so a migration cannot be half applied by accident.

The connection string is never stored in the repository. Put it in
`backend/.env` as `DATABASE_URL`, or pass it with `--database-url`.

    python -m scripts.apply_migrations --check
    python -m scripts.apply_migrations
    python -m scripts.apply_migrations --only 202611010002_chat_agent_slots.sql
"""

import argparse
import os
import sys
from pathlib import Path

if str(Path(__file__).resolve().parents[1]) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

MIGRATIONS_DIR = Path(__file__).resolve().parents[1] / "supabase" / "migrations"


def _database_url(explicit: str | None) -> str:
    """Read the connection string from the argument, the environment or .env.

    The value is used to open a connection and is never printed.
    """
    if explicit:
        return explicit
    from dotenv import dotenv_values

    root = Path(__file__).resolve().parents[1]
    for path in (root / ".env", root.parent / ".env"):
        if path.is_file():
            value = dotenv_values(path, encoding="utf-8").get("DATABASE_URL")
            if value:
                return value
    return os.getenv("DATABASE_URL", "")


def _migration_files(only: str | None) -> list[Path]:
    """List the migration files in order, optionally filtered by name."""
    files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not only:
        return files
    selected = [path for path in files if path.name == only]
    if not selected:
        raise SystemExit(f"No migration named {only} in {MIGRATIONS_DIR}")
    return selected


def _placeholder_password(url: str) -> bool:
    """Report whether the connection string still holds the template value."""
    return "[YOUR-PASSWORD]" in url or ":PASSWORD@" in url


def _check(connection) -> list[dict]:
    """Report which migration objects already exist."""
    rows = connection.execute(
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name IN (
            'budget_plans', 'daily_allocations', 'budget_plan_events',
            'ai_chat_sessions', 'ai_chat_messages'
          )
        ORDER BY table_name
        """
    ).fetchall()
    present = {row[0] for row in rows}
    columns = connection.execute(
        """
        SELECT column_name FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'ai_chat_messages'
          AND column_name IN ('tool_name', 'tool_args', 'tool_result')
        """
    ).fetchall()
    return [
        {
            "table": name,
            "exists": name in present,
        }
        for name in (
            "budget_plans",
            "daily_allocations",
            "budget_plan_events",
        )
    ] + [
        {
            "column": f"ai_chat_messages.{row[0]}",
            "exists": True,
        }
        for row in columns
    ]


def main() -> None:
    """Apply the migrations, or report the current state."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-url", help="PostgreSQL connection string")
    parser.add_argument("--only", help="Apply one migration file by name")
    parser.add_argument(
        "--check",
        action="store_true",
        help="Only report what is already applied",
    )
    args = parser.parse_args()

    url = _database_url(args.database_url)
    if not url:
        raise SystemExit(
            "No DATABASE_URL found. Add it to backend/.env as:\n"
            "  DATABASE_URL=postgresql://postgres.<project-ref>:<password>"
            "@aws-0-<region>.pooler.supabase.com:6543/postgres\n"
            "The Supabase Dashboard shows it under Settings > Database."
        )
    if _placeholder_password(url):
        raise SystemExit(
            "DATABASE_URL still holds the template password.\n"
            "Replace [YOUR-PASSWORD] in backend/.env with the database password\n"
            "from Supabase Dashboard > Settings > Database."
        )

    try:
        import psycopg
    except ImportError as error:
        raise SystemExit(
            'psycopg is not installed. Run: pip install "psycopg[binary]"'
        ) from error

    files = _migration_files(args.only)
    # The migration files carry their own BEGIN/COMMIT, so the connection
    # runs in autocommit mode. A failure inside a file rolls that file back
    # on its own; the script then stops instead of applying the next one.
    try:
        connection = psycopg.connect(url, autocommit=True, connect_timeout=15)
    except Exception as error:  # noqa: BLE001 - reported to the operator
        raise SystemExit(f"Could not connect to the database: {error}") from error

    with connection:
        if args.check:
            for entry in _check(connection):
                print(entry)
            return
        for path in files:
            sql = path.read_text(encoding="utf-8")
            try:
                connection.execute(sql)
            except Exception as error:  # noqa: BLE001 - reported to the operator
                raise SystemExit(
                    f"{path.name} failed and was rolled back: {error}"
                ) from error
            print(f"applied {path.name}")
        for entry in _check(connection):
            print(entry)


if __name__ == "__main__":
    main()
