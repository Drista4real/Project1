"""Tests for the plan window read by the remaining balance, in Vietnam time."""

from datetime import UTC, date, datetime, timedelta

import pytest

from app.domain.budget_plan import LOCAL_TIMEZONE, plan_window_bounds

START = date(2026, 11, 1)


def test_the_window_opens_at_midnight_in_ho_chi_minh():
    as_of = datetime(2026, 11, 10, 12, 0, tzinfo=LOCAL_TIMEZONE)
    start, end = plan_window_bounds(START, 30, as_of)
    assert start == datetime(2026, 10, 31, 17, 0, tzinfo=UTC)
    assert start.utcoffset() == timedelta(hours=7)
    assert end == as_of


def test_a_preview_in_another_timezone_ends_at_the_same_moment():
    as_of = datetime(2026, 11, 10, 5, 0, tzinfo=UTC)
    _, end = plan_window_bounds(START, 30, as_of)
    assert end == datetime(2026, 11, 10, 12, 0, tzinfo=LOCAL_TIMEZONE)


def test_a_preview_after_the_plan_ends_at_the_last_local_midnight():
    as_of = datetime(2026, 12, 15, 9, 0, tzinfo=LOCAL_TIMEZONE)
    _, end = plan_window_bounds(START, 30, as_of)
    assert end == datetime(2026, 11, 30, 17, 0, tzinfo=UTC)


def test_a_preview_before_the_plan_gives_an_empty_window():
    as_of = datetime(2026, 10, 31, 23, 59, tzinfo=LOCAL_TIMEZONE)
    start, end = plan_window_bounds(START, 30, as_of)
    assert start == end


def test_a_preview_without_a_timezone_is_rejected():
    with pytest.raises(ValueError):
        plan_window_bounds(START, 30, datetime(2026, 11, 10, 12, 0))
