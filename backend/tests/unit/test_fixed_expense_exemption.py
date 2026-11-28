"""The plan spending E exempts marked fixed expenses up to the plan's amount."""

from decimal import Decimal

import pytest

from app.domain.budget_plan import exempt_fixed_expenses


@pytest.mark.parametrize(
    ("total", "marked", "fixed", "expected"),
    [
        # M = 0: nothing is exempted.
        ("2900000", "0", "3000000", "2900000"),
        # M < F: the whole marked amount is exempted.
        ("2900000", "2500000", "3000000", "400000"),
        # M = F: exactly the planned fixed expenses are exempted.
        ("3400000", "3000000", "3000000", "400000"),
        # M > F: the excess over the plan still counts as spending.
        ("3900000", "3500000", "3000000", "900000"),
    ],
)
def test_marked_fixed_expenses_are_exempted_up_to_the_plan(
    total, marked, fixed, expected
):
    assert exempt_fixed_expenses(
        Decimal(total), Decimal(marked), Decimal(fixed)
    ) == Decimal(expected)
