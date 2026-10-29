"""Validate generated date ranges before modifying existing data."""

from datetime import date

import pytest

from scripts.generate_synthetic_data import generate_balances


def test_invalid_date_range_does_not_overwrite_existing_data(tmp_path):
    existing = tmp_path / "balance_fixed.csv"
    existing.write_text("original", encoding="utf-8")

    with pytest.raises(OverflowError):
        generate_balances(tmp_path, balance_days=2, start_date=date.max)

    assert existing.read_text(encoding="utf-8") == "original"
    assert not (tmp_path / "balance_flexible.csv").exists()
