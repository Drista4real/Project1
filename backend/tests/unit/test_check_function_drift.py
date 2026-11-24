import sys
import types
from dataclasses import replace

import pytest

from scripts.check_function_drift import FunctionRow, compare_functions, main

REBALANCE = "public.rebalance_plan(bigint,integer,jsonb,jsonb,uuid)"
VALIDATE = "public.validate_envelope_capacity(uuid,date)"


def _row(signature: str = REBALANCE, **changes: object) -> FunctionRow:
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


def test_identical_catalogs_have_no_difference() -> None:
    rows = [_row(), _row(VALIDATE)]

    assert compare_functions(rows, list(rows)) == []


def test_a_stale_body_is_reported_with_both_values() -> None:
    target = _row(body_md5="f927dd00000000000000000000000000", body_length=6519)

    differences = compare_functions([_row()], [target])

    assert len(differences) == 1
    assert REBALANCE in differences[0]
    assert "13c46986" in differences[0] and "f927dd" in differences[0]
    assert "7261" in differences[0] and "6519" in differences[0]


def test_a_function_missing_from_the_target_is_reported() -> None:
    differences = compare_functions([_row(), _row(VALIDATE)], [_row()])

    assert differences == [f"missing in target: {VALIDATE}"]


def test_an_extra_function_in_the_target_is_reported() -> None:
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
    reference = _row()
    target = replace(reference, **{field: not getattr(reference, field)})

    differences = compare_functions([reference], [target])

    assert len(differences) == 1
    assert field in differences[0]


def test_a_config_difference_is_reported() -> None:
    differences = compare_functions([_row()], [_row(config=None)])

    assert len(differences) == 1
    assert "config" in differences[0]


def test_connection_failure_never_prints_the_connection_string(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    secret = "postgresql://postgres:hunter2@db.example.test:5432/postgres"

    def refuse(conninfo: str, **_: object) -> None:
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
