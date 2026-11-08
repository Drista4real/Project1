// The value objects exchanged with the deterministic budget engine.

import 'package:project_one/core/network/json_numbers.dart';

/// One planning group inside a plan.
class PlanGroup {
  const PlanGroup({
    required this.groupKey,
    required this.pillar,
    required this.dailyAmount,
    required this.totalAmount,
  });

  final String groupKey;
  final String pillar;
  final num dailyAmount;
  final num totalAmount;

  factory PlanGroup.fromJson(Map<String, dynamic> json) => PlanGroup(
    groupKey: json['group_key'] as String? ?? '',
    pillar: json['pillar'] as String? ?? 'needs',
    dailyAmount: readDouble(json['daily_amount']) ?? 0,
    totalAmount: readDouble(json['total_amount']) ?? 0,
  );
}

/// One budget plan with its computed allocation.
class BudgetPlan {
  const BudgetPlan({
    required this.id,
    required this.title,
    required this.status,
    required this.totalIncome,
    required this.durationDays,
    required this.savingsTarget,
    required this.fixedExpenses,
    required this.startDate,
    required this.spendableBudget,
    required this.dailyAllowance,
    required this.survivalFloor,
    required this.planVersion,
    required this.configVersion,
    required this.groups,
  });

  final int id;
  final String title;
  final String status;
  final num totalIncome;
  final int durationDays;
  final num savingsTarget;
  final num fixedExpenses;
  final DateTime? startDate;
  final num spendableBudget;
  final num dailyAllowance;
  final num survivalFloor;
  final int planVersion;
  final String configVersion;
  final List<PlanGroup> groups;

  factory BudgetPlan.fromJson(Map<String, dynamic> json) => BudgetPlan(
    id: readInt(json['id']) ?? 0,
    title: json['title'] as String? ?? 'Kế hoạch chi tiêu',
    status: json['status'] as String? ?? 'ACTIVE',
    totalIncome: readDouble(json['total_income']) ?? 0,
    durationDays: readInt(json['duration_days']) ?? 0,
    savingsTarget: readDouble(json['savings_target']) ?? 0,
    fixedExpenses: readDouble(json['fixed_expenses']) ?? 0,
    startDate: DateTime.tryParse('${json['start_date']}'),
    spendableBudget: readDouble(json['spendable_budget']) ?? 0,
    dailyAllowance: readDouble(json['daily_allowance']) ?? 0,
    survivalFloor: readDouble(json['survival_floor']) ?? 0,
    planVersion: readInt(json['plan_version']) ?? 1,
    configVersion: json['config_version'] as String? ?? 'budget-engine-v1',
    groups: ((json['groups'] as List?) ?? const [])
        .map((item) => PlanGroup.fromJson((item as Map).cast<String, dynamic>()))
        .toList(),
  );
}

/// One group allocation for one day of a plan.
class DailyAllocation {
  const DailyAllocation({
    required this.dayIndex,
    required this.allocDate,
    required this.groupKey,
    required this.pillar,
    required this.amount,
    required this.actualSpent,
  });

  final int dayIndex;
  final DateTime? allocDate;
  final String groupKey;
  final String pillar;
  final num amount;
  final num actualSpent;

  factory DailyAllocation.fromJson(Map<String, dynamic> json) => DailyAllocation(
    dayIndex: readInt(json['day_index']) ?? 0,
    allocDate: DateTime.tryParse('${json['alloc_date']}'),
    groupKey: json['group_key'] as String? ?? '',
    pillar: json['pillar'] as String? ?? 'needs',
    amount: readDouble(json['amount']) ?? 0,
    actualSpent: readDouble(json['actual_spent']) ?? 0,
  );
}

/// The deterministic verdict for a proposed purchase.
class PurchaseImpact {
  const PurchaseImpact({
    required this.level,
    required this.planId,
    required this.dailyAllowanceNow,
    required this.dailyAllowanceAfter,
    required this.survivalFloor,
    required this.remainingDays,
    required this.reason,
  });

  final String level;
  final int planId;
  final num dailyAllowanceNow;
  final num? dailyAllowanceAfter;
  final num survivalFloor;
  final int remainingDays;
  final String reason;

  bool get isSafe => level == 'SAFE';
  bool get isWarning => level == 'WARNING_REBALANCE_NEEDED';
  bool get isCritical => level == 'CRITICAL_DANGER';
  bool get isUnknown => level == 'INSUFFICIENT_DATA';

  factory PurchaseImpact.fromJson(Map<String, dynamic> json) => PurchaseImpact(
    level: json['level'] as String? ?? 'INSUFFICIENT_DATA',
    planId: readInt(json['plan_id']) ?? 0,
    dailyAllowanceNow: readDouble(json['daily_allowance_now']) ?? 0,
    dailyAllowanceAfter: readDouble(json['daily_allowance_after']),
    survivalFloor: readDouble(json['survival_floor']) ?? 0,
    remainingDays: readInt(json['remaining_days']) ?? 0,
    reason: json['reason'] as String? ?? '',
  );
}
