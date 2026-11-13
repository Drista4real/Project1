import 'package:flutter/material.dart';
import 'package:project_one/features/budget/models/envelope_pillar.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

import '../models/budget_plan_models.dart';

/// The plan's groups mapped onto the four envelope pillars.
///
/// The plan is a projection: a group only carries the pillar it belongs to,
/// and the envelope limits stay in `public.budgets` (ADR 0005).
const planGroupLabels = {
  'food': 'Ăn uống',
  'transport': 'Đi lại',
  'lifestyle': 'Chi tiêu linh hoạt',
  'other': 'Dự phòng',
};

const planGroupIcons = {
  'food': Icons.restaurant_outlined,
  'transport': Icons.directions_bus_outlined,
  'lifestyle': Icons.shopping_bag_outlined,
  'other': Icons.savings_outlined,
};

/// The pillar a planning group belongs to.
EnvelopePillar planPillarOf(String groupKey) => switch (groupKey) {
  'food' => EnvelopePillar.needs,
  'transport' => EnvelopePillar.needs,
  'lifestyle' => EnvelopePillar.wants,
  _ => EnvelopePillar.unexpected,
};

/// The split of the plan across its groups.
class PlanGroupList extends StatelessWidget {
  const PlanGroupList({super.key, required this.plan});

  final BudgetPlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final group in plan.groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  planGroupIcons[group.groupKey] ?? Icons.category_outlined,
                  size: 18,
                  color: planPillarOf(group.groupKey).color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    planGroupLabels[group.groupKey] ?? group.groupKey,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '${formatVnd(group.dailyAmount)}/ngày',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
