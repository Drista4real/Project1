"""Tests for the deterministic budget engine domain calculations."""

from datetime import date
from decimal import Decimal
from uuid import uuid4

import pytest

from app.application.budget_plan import validate_rebalance_payload
from app.domain.budget_plan import (
    BudgetPlan,
    EnvelopeCapacity,
    GroupRatios,
    RebalanceInfeasible,
    build_daily_allocations,
    compute_plan_totals,
    daily_group_amounts,
    evaluate_purchase_impact,
    propose_rebalance,
)
from app.domain.transactions import TransactionError


def _totals(
    income: str = "8000000",
    fixed: str = "3000000",
    savings: str = "2000000",
    days: int = 30,
    ratios: GroupRatios | None = None,
    floor: str | None = None,
):
    return compute_plan_totals(
        total_income=Decimal(income),
        fixed_expenses=Decimal(fixed),
        savings_target=Decimal(savings),
        duration_days=days,
        group_ratios=ratios or GroupRatios(),
        survival_floor_override=Decimal(floor) if floor else None,
    )


class TestPlanTotals:
    """Deterministic plan derivation."""

    def test_spendable_budget_and_daily_allowance(self):
        totals = _totals()
        assert totals.spendable_budget == Decimal("3000000.00")
        assert totals.daily_allowance == Decimal("100000.00")

    def test_survival_floor_defaults_to_fixed_expenses_per_day(self):
        totals = _totals()
        assert totals.survival_floor == Decimal("100000.00")

    def test_survival_floor_override_is_used(self):
        totals = _totals(floor="70000")
        assert totals.survival_floor == Decimal("70000.00")

    def test_group_split_sums_to_spendable_budget(self):
        totals = _totals()
        assert sum(group.total_amount for group in totals.groups) == Decimal(
            "3000000.00"
        )

    def test_group_split_follows_default_ratios(self):
        totals = _totals()
        by_key = {group.group_key: group.total_amount for group in totals.groups}
        assert by_key["food"] == Decimal("1800000.00")
        assert by_key["transport"] == Decimal("450000.00")
        assert by_key["lifestyle"] == Decimal("750000.00")

    def test_group_split_honours_custom_ratios(self):
        totals = _totals(
            ratios=GroupRatios(food=50, transport=20, lifestyle=30)
        )
        by_key = {group.group_key: group.total_amount for group in totals.groups}
        assert by_key["food"] == Decimal("1500000.00")
        assert by_key["transport"] == Decimal("600000.00")
        assert by_key["lifestyle"] == Decimal("900000.00")

    def test_non_positive_spendable_budget_is_rejected(self):
        with pytest.raises(ValueError, match="must exceed"):
            _totals(income="3000000", fixed="3000000", savings="2000000")

    def test_ratios_must_sum_to_100(self):
        with pytest.raises(ValueError, match="add up to 100"):
            GroupRatios(food=50, transport=20, lifestyle=25)


class TestDailyAllocations:
    """Per-day projection."""

    def test_daily_amounts_sum_back_to_the_total(self):
        amounts = daily_group_amounts(Decimal("1000000.00"), 30)
        assert len(amounts) == 30
        assert sum(amounts) == Decimal("1000000.00")

    def test_allocations_cover_every_group_and_day(self):
        totals = _totals()
        allocations = build_daily_allocations(
            totals=totals, duration_days=30, start_date=date(2026, 11, 1)
        )
        assert len(allocations) == 90
        assert {item.group_key for item in allocations} == {
            "food",
            "transport",
            "lifestyle",
        }
        assert allocations[0].alloc_date == date(2026, 11, 1)

    def test_allocation_totals_match_the_plan(self):
        totals = _totals()
        allocations = build_daily_allocations(
            totals=totals, duration_days=30, start_date=date(2026, 11, 1)
        )
        for group in totals.groups:
            spent = sum(
                item.amount
                for item in allocations
                if item.group_key == group.group_key
            )
            assert spent == group.total_amount


def _plan(**overrides) -> BudgetPlan:
    totals = _totals()
    payload = {
        "id": 42,
        "title": "Kế hoạch chi tiêu",
        "status": "ACTIVE",
        "total_income": Decimal("8000000"),
        "duration_days": 30,
        "savings_target": Decimal("2000000"),
        "fixed_expenses": Decimal("3000000"),
        "start_date": date(2026, 11, 1),
        "spendable_budget": Decimal("3000000"),
        "daily_allowance": Decimal("100000"),
        "survival_floor": Decimal("100000"),
        "plan_version": 1,
        "config_version": "budget-engine-v1",
        "groups": totals.groups,
    }
    payload.update(overrides)
    return BudgetPlan(**payload)


class TestPurchaseImpact:
    """Pre-purchase classification."""

    def test_missing_history_reports_insufficient_data(self):
        result = evaluate_purchase_impact(
            plan=_plan(), current_day=3, amount=Decimal("800000"),
            remaining_balance=None,
        )
        assert result.level == "INSUFFICIENT_DATA"
        assert result.daily_allowance_after is None

    def test_small_purchase_is_safe(self):
        result = evaluate_purchase_impact(
            plan=_plan(survival_floor=Decimal("50000")),
            current_day=3,
            amount=Decimal("100000"),
            remaining_balance=Decimal("2800000"),
        )
        assert result.level == "SAFE"
        assert result.daily_allowance_after is not None

    def test_default_survival_floor_equals_the_daily_allowance(self):
        # The default floor is fixed expenses per day, so every purchase that
        # lowers the daily allowance is critical. The user can override it.
        result = evaluate_purchase_impact(
            plan=_plan(),
            current_day=3,
            amount=Decimal("100000"),
            remaining_balance=Decimal("2800000"),
        )
        assert result.level == "CRITICAL_DANGER"

    def test_purchase_below_survival_floor_is_critical(self):
        result = evaluate_purchase_impact(
            plan=_plan(survival_floor=Decimal("70000")),
            current_day=3,
            amount=Decimal("1000000"),
            remaining_balance=Decimal("2800000"),
        )
        assert result.level == "CRITICAL_DANGER"

    def test_purchase_above_allowance_but_above_floor_warns(self):
        result = evaluate_purchase_impact(
            plan=_plan(survival_floor=Decimal("70000")),
            current_day=3,
            amount=Decimal("500000"),
            remaining_balance=Decimal("3500000"),
        )
        assert result.level == "WARNING_REBALANCE_NEEDED"

    def test_day_outside_plan_is_rejected(self):
        with pytest.raises(ValueError, match="inside the plan"):
            evaluate_purchase_impact(
                plan=_plan(), current_day=31, amount=Decimal("1000"),
                remaining_balance=Decimal("1000"),
            )


class TestProposeRebalance:
    """Deterministic rebalance proposals."""

    def _capacity(self, **pillars) -> dict[str, EnvelopeCapacity]:
        capacity = {
            pillar: EnvelopeCapacity(pillar=pillar) for pillar in pillars
        }
        for pillar, amount in pillars.items():
            capacity[pillar] = EnvelopeCapacity(
                pillar=pillar, category_limit_total=Decimal(amount)
            )
        return capacity

    def test_purchase_reduces_the_cuttable_pillar_first(self):
        totals = _totals()
        proposal = propose_rebalance(
            totals=totals,
            duration_days=30,
            current_day=3,
            purchase_amount=Decimal("800000"),
            remaining_budget=Decimal("2900000"),
            capacity={},
        )
        after = {item.group_key: item.daily_amount for item in proposal.allocations}
        # The wants pillar absorbs the cut first; needs stays untouched.
        assert after["lifestyle"] == Decimal("0.00")
        assert after["food"] == Decimal("60000.00")
        assert after["transport"] == Decimal("15000.00")
        assert proposal.daily_allowance_after == Decimal("75000.00")

    def test_needs_is_cut_only_after_the_cuttable_pillars(self):
        totals = _totals()
        proposal = propose_rebalance(
            totals=totals,
            duration_days=30,
            current_day=3,
            purchase_amount=Decimal("800000"),
            remaining_budget=Decimal("2600000"),
            capacity={},
        )
        after = {item.group_key: item.daily_amount for item in proposal.allocations}
        assert after["lifestyle"] == Decimal("0.00")
        assert after["food"] < Decimal("60000.00")
        assert after["transport"] < Decimal("15000.00")

    def test_funded_pillar_cannot_be_zeroed(self):
        totals = _totals()
        capacity = self._capacity(wants=Decimal("900000"))
        with pytest.raises(RebalanceInfeasible):
            propose_rebalance(
                totals=totals,
                duration_days=30,
                current_day=3,
                purchase_amount=Decimal("800000"),
                remaining_budget=Decimal("2600000"),
                capacity=capacity,
            )

    def test_purchase_beyond_the_plan_is_infeasible(self):
        totals = _totals()
        with pytest.raises(RebalanceInfeasible):
            propose_rebalance(
                totals=totals,
                duration_days=30,
                current_day=3,
                purchase_amount=Decimal("100000000"),
                remaining_budget=Decimal("2600000"),
                capacity={},
            )

    def test_proposal_is_deterministic(self):
        totals = _totals()
        first = propose_rebalance(
            totals=totals,
            duration_days=30,
            current_day=3,
            purchase_amount=Decimal("400000"),
            remaining_budget=Decimal("2600000"),
            capacity={},
        )
        second = propose_rebalance(
            totals=totals,
            duration_days=30,
            current_day=3,
            purchase_amount=Decimal("400000"),
            remaining_budget=Decimal("2600000"),
            capacity={},
        )
        assert first.allocations == second.allocations
        assert first.daily_allowance_after == second.daily_allowance_after

    def test_daily_allowance_matches_the_remaining_budget(self):
        totals = _totals()
        proposal = propose_rebalance(
            totals=totals,
            duration_days=30,
            current_day=3,
            purchase_amount=Decimal("400000"),
            remaining_budget=Decimal("2600000"),
            capacity={},
        )
        assert proposal.remaining_days == 28
        expected = (Decimal("2600000") - Decimal("400000")) / 28
        assert proposal.daily_allowance_after == expected.quantize(Decimal("0.01"))


def _rebalance_payload(**overrides) -> dict:
    """A valid rebalance body as the client sends it."""
    payload = {
        "plan_id": 42,
        "expected_version": 3,
        "current_day": 2,
        "purchase_amount": "0",
        "allocations": [
            {
                "group_key": "food",
                "pillar": "needs",
                "daily_amount": "480000.00",
            }
        ],
        "idempotency_key": str(uuid4()),
    }
    payload.update(overrides)
    return payload


class TestRebalancePayloadValidation:
    """The payload is validated before anything is written."""

    def test_a_valid_payload_is_accepted(self):
        request = validate_rebalance_payload(_rebalance_payload())
        assert request.plan_id == 42
        assert request.expected_version == 3
        assert request.allocations[0].group_key == "food"

    def test_a_missing_expected_version_is_refused(self):
        payload = _rebalance_payload()
        del payload["expected_version"]
        with pytest.raises(TransactionError) as caught:
            validate_rebalance_payload(payload)
        assert caught.value.status == 422

    def test_a_missing_idempotency_key_is_refused(self):
        payload = _rebalance_payload()
        del payload["idempotency_key"]
        with pytest.raises(TransactionError) as caught:
            validate_rebalance_payload(payload)
        assert caught.value.status == 422

    def test_an_unknown_field_is_refused(self):
        payload = _rebalance_payload(user_id="someone-else")
        with pytest.raises(TransactionError) as caught:
            validate_rebalance_payload(payload)
        assert caught.value.status == 422

    def test_a_version_below_one_is_refused(self):
        with pytest.raises(TransactionError) as caught:
            validate_rebalance_payload(_rebalance_payload(expected_version=0))
        assert caught.value.status == 422

    def test_an_empty_allocation_list_is_refused(self):
        with pytest.raises(TransactionError) as caught:
            validate_rebalance_payload(_rebalance_payload(allocations=[]))
        assert caught.value.status == 422

    def test_a_negative_daily_amount_is_refused(self):
        payload = _rebalance_payload(
            allocations=[
                {
                    "group_key": "food",
                    "pillar": "needs",
                    "daily_amount": "-1.00",
                }
            ]
        )
        with pytest.raises(TransactionError) as caught:
            validate_rebalance_payload(payload)
        assert caught.value.status == 422