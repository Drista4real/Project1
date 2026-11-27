import sys
import types
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import astuple, replace

import pytest

from scripts.check_function_drift import FunctionRow, compare_functions, main

REBALANCE = "public.rebalance_plan(bigint,integer,jsonb,jsonb,uuid)"
VALIDATE = "public.validate_envelope_capacity(uuid,date)"
REFERENCE_URL = "postgresql://reference.example.test/postgres"
TARGET_URL = "postgresql://target.example.test/postgres"


def _row(signature: str = REBALANCE, **changes: object) -> FunctionRow:
    """Build a catalog row that matches the repository definition."""
    row = FunctionRow(
        signature=signature,
        body_md5="13c46986a198f1d80363d710e1e30a99",
        body_length=7261,
        security_definer=True,
        config=('search_path=""',),
        anon_execute=False,
        authenticated_execute=True,
        service_role_execute=True,
    )
    return replace(row, **changes)


def _catalog(rows: list[FunctionRow]) -> list[tuple[object, ...]]:
    """Return rows shaped like the driver returns them, config as a list."""
    return [
        (*astuple(row)[:4], list(row.config) if row.config else None, *astuple(row)[5:])
        for row in rows
    ]


def _run_main(
    monkeypatch: pytest.MonkeyPatch,
    reference: list[FunctionRow],
    target: list[FunctionRow],
) -> int | str | None:
    """Run main() against a fake psycopg and return its exit code."""
    catalogs = {REFERENCE_URL: _catalog(reference), TARGET_URL: _catalog(target)}

    @contextmanager
    def connect(conninfo: str, **_: object) -> Iterator[types.SimpleNamespace]:
        """Serve the canned catalog of one database."""
        rows = catalogs[conninfo]
        result = types.SimpleNamespace(fetchall=lambda: rows, fetchone=lambda: (0,))
        yield types.SimpleNamespace(execute=lambda _sql: result)

    monkeypatch.setitem(sys.modules, "psycopg", types.SimpleNamespace(connect=connect))
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "check_function_drift",
            "--reference-url",
            REFERENCE_URL,
            "--database-url",
            TARGET_URL,
        ],
    )
    try:
        main()
    except SystemExit as exited:
        return exited.code
    return 0


def test_identical_catalogs_have_no_difference() -> None:
    """Two catalogs with the same rows compare equal."""
    rows = [_row(), _row(VALIDATE)]

    assert compare_functions(rows, list(rows)) == []


def test_a_stale_body_is_reported_with_both_values() -> None:
    """A different body is one difference naming both md5 values and lengths."""
    target = _row(body_md5="f927dd00000000000000000000000000", body_length=6519)

    differences = compare_functions([_row()], [target])

    assert len(differences) == 1
    assert REBALANCE in differences[0]
    assert "13c46986" in differences[0] and "f927dd" in differences[0]
    assert "7261" in differences[0] and "6519" in differences[0]


def test_a_function_missing_from_the_target_is_reported() -> None:
    """A function only the reference has is reported as missing."""
    differences = compare_functions([_row(), _row(VALIDATE)], [_row()])

    assert differences == [f"missing in target: {VALIDATE}"]


def test_an_extra_function_in_the_target_is_reported() -> None:
    """A function only the target has is reported as extra."""
    differences = compare_functions([_row()], [_row(), _row(VALIDATE)])

    assert differences == [f"extra in target: {VALIDATE}"]


@pytest.mark.parametrize(
    "field",
    [
        "security_definer",
        "anon_execute",
        "authenticated_execute",
        "service_role_execute",
    ],
)
def test_a_flag_difference_is_reported(field: str) -> None:
    """Each flag that differs is reported by name."""
    reference = _row()
    target = replace(reference, **{field: not getattr(reference, field)})

    differences = compare_functions([reference], [target])

    assert len(differences) == 1
    assert field in differences[0]


def test_a_config_difference_is_reported() -> None:
    """Function settings that differ are reported."""
    differences = compare_functions([_row()], [_row(config=None)])

    assert len(differences) == 1
    assert "config" in differences[0]


def test_a_search_path_difference_shows_both_values() -> None:
    """search_path is not a secret, so both values stay readable."""
    differences = compare_functions([_row()], [_row(config=("search_path=public",))])

    assert len(differences) == 1
    assert 'search_path=""' in differences[0]
    assert "search_path=public" in differences[0]


def test_other_setting_values_never_reach_the_report(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """A setting other than search_path shows its name, never its value."""
    target = _row(config=('search_path=""', "app.dsn=postgresql://user:secret@host/db"))

    code = _run_main(monkeypatch, [_row()], [target])

    output = capsys.readouterr()
    shown = f"{code}{output.out}{output.err}"
    assert code not in (0, None)
    assert "app.dsn" in shown
    assert "secret" not in shown and "user:" not in shown and "@host" not in shown


def test_connection_failure_never_prints_the_connection_string(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """A failed connection names the database, not its connection string."""
    secret = "postgresql://postgres:hunter2@db.example.test:5432/postgres"

    def refuse(conninfo: str, **_: object) -> None:
        """Fail the way a driver can: by quoting the connection string."""
        raise RuntimeError(f"could not connect with {conninfo}")

    monkeypatch.setitem(sys.modules, "psycopg", types.SimpleNamespace(connect=refuse))
    monkeypatch.setattr(
        sys,
        "argv",
        ["check_function_drift", "--reference-url", secret, "--database-url", secret],
    )

    with pytest.raises(SystemExit) as raised:
        main()

    output = capsys.readouterr()
    shown = f"{raised.value.code}{output.out}{output.err}"
    assert raised.value.code not in (0, None)
    assert "hunter2" not in shown and "db.example.test" not in shown
