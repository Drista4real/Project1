"""Exercise transaction separators and long whitespace runs."""

import pytest

from app.infrastructure.ai.input_rules import _explicit_clauses


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("cơm 20k và bánh 30k", ["cơm 20k", "bánh 30k"]),
        ("a,1; b\n c", ["a,1", "b", "c"]),
        ("a \nRỒI  b", ["a", "b"]),
        ("a" + " " * 100_000 + "b", ["a" + " " * 100_000 + "b"]),
    ],
    ids=["conjunction", "punctuation", "mixed-whitespace", "long-whitespace"],
)
def test_explicit_clauses(text: str, expected: list[str]) -> None:
    assert _explicit_clauses(text) == expected
