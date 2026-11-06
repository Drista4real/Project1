import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/chat/models/chat_models.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';

void main() {
  group('BudgetSlots', () {
    test('reads the amounts the backend sent as strings', () {
      // The backend keeps the amounts as Decimal and serialises them as
      // strings, so a client that only accepts a JSON number would fail.
      final slots = BudgetSlots.fromJson(const {
        'total_income': '8000000',
        'duration_days': 7,
        'savings_target': '1000000',
        'fixed_expenses': '1400000',
      });

      expect(slots.totalIncome, 8000000);
      expect(slots.durationDays, 7);
      expect(slots.savingsTarget, 1000000);
      expect(slots.fixedExpenses, 1400000);
      expect(slots.isComplete, isTrue);
    });

    test('reads the amounts the backend sent as numbers', () {
      final slots = BudgetSlots.fromJson(const {
        'total_income': 8000000,
        'duration_days': 7,
        'savings_target': 1000000,
        'fixed_expenses': 1400000,
      });

      expect(slots.totalIncome, 8000000);
      expect(slots.durationDays, 7);
    });

    test('leaves the missing amounts empty', () {
      final slots = BudgetSlots.fromJson(const {});

      expect(slots.totalIncome, isNull);
      expect(slots.durationDays, isNull);
      expect(slots.isComplete, isFalse);
    });
  });

  group('ChatTurn', () {
    test('reads a turn that carries collected slots', () {
      final turn = ChatTurn.fromJson(const {
        'session_id': 5,
        'reply': 'Đã tạo kế hoạch.',
        'tool_calls': [
          {'name': 'create_budget_plan', 'arguments': {}},
        ],
        'slots': {
          'total_income': '8000000',
          'duration_days': 7,
          'savings_target': '1000000',
          'fixed_expenses': '1400000',
        },
      });

      expect(turn.sessionId, 5);
      expect(turn.reply, 'Đã tạo kế hoạch.');
      expect(turn.toolName, 'create_budget_plan');
      expect(turn.slots.totalIncome, 8000000);
      expect(turn.slots.durationDays, 7);
    });
  });

  group('BudgetPlan', () {
    test('reads a plan whose amounts are strings', () {
      final plan = BudgetPlan.fromJson(const {
        'id': 1,
        'title': 'Kế hoạch tháng',
        'status': 'ACTIVE',
        'total_income': '8000000.00',
        'duration_days': 7,
        'savings_target': '1000000.00',
        'fixed_expenses': '1400000.00',
        'start_date': '2026-11-01',
        'spendable_budget': '5600000.00',
        'daily_allowance': '800000.00',
        'survival_floor': '200000.00',
        'plan_version': 1,
        'config_version': 'budget-engine-v1',
        'groups': [
          {
            'group_key': 'food',
            'pillar': 'needs',
            'daily_amount': '480000.00',
            'total_amount': '3360000.00',
          },
        ],
      });

      expect(plan.totalIncome, 8000000);
      expect(plan.durationDays, 7);
      expect(plan.spendableBudget, 5600000);
      expect(plan.groups.single.dailyAmount, 480000);
    });
  });

  group('PurchaseImpact', () {
    test('reads a verdict whose amounts are strings', () {
      final impact = PurchaseImpact.fromJson(const {
        'level': 'WARNING_REBALANCE_NEEDED',
        'plan_id': 1,
        'daily_allowance_now': '800000.00',
        'daily_allowance_after': '700000.00',
        'survival_floor': '200000.00',
        'remaining_days': 3,
        'reason': 'Vượt hạn mức ngày.',
      });

      expect(impact.planId, 1);
      expect(impact.dailyAllowanceNow, 800000);
      expect(impact.dailyAllowanceAfter, 700000);
      expect(impact.remainingDays, 3);
      expect(impact.isWarning, isTrue);
    });
  });
}
