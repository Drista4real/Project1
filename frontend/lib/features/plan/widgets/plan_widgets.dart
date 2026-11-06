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

/// The header of the plan: its title, version and the two key figures.
class PlanHeaderCard extends StatelessWidget {
  const PlanHeaderCard({super.key, required this.plan});

  final BudgetPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [EnvelopeStyle.primary, Color(0xFF2D5A43)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: Color(0xFFBCEECF),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'KẾ HOẠCH ${plan.durationDays} NGÀY',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: .6,
                    color: Color(0xFFBCEECF),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'v${plan.planVersion}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                formatVnd(plan.dailyAllowance),
                key: const ValueKey('plan-daily-allowance'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Hạn mức chi tiêu mỗi ngày',
            style: TextStyle(fontSize: 12, color: Color(0xFFD7EADC)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric(
                  'Tổng có thể chi',
                  formatVnd(plan.spendableBudget),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _metric('Sàn sống', formatVnd(plan.survivalFloor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Thu ${formatVnd(plan.totalIncome)} · Chi phí cố định '
            '${formatVnd(plan.fixedExpenses)} · Tiết kiệm '
            '${formatVnd(plan.savingsTarget)}',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFD7EADC),
              height: 1.5,
            ),
          ),
          if (plan.status != 'ACTIVE')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Trạng thái: ${plan.status}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFD7EADC),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFFD7EADC)),
      ),
      const SizedBox(height: 5),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  );
}

/// One pillar row: its daily limit, today's spending and what is left.
class PlanPillarRow extends StatelessWidget {
  const PlanPillarRow({
    super.key,
    required this.pillar,
    required this.limit,
    required this.spent,
  });

  final EnvelopePillar pillar;
  final num limit;
  final num spent;

  @override
  Widget build(BuildContext context) {
    final remaining = limit - spent;
    final over = remaining < 0;
    final progress = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: pillar.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pillar.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${formatVnd(spent)} / ${formatVnd(limit)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              semanticsLabel: 'Mức sử dụng ${pillar.title}',
              color: over ? const Color(0xFFFE875D) : pillar.barColor,
              backgroundColor: pillar.tint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            over
                ? 'Vượt ${formatVnd(remaining.abs())}'
                : 'Còn lại ${formatVnd(remaining)}',
            style: TextStyle(
              fontSize: 11,
              color: over
                  ? const Color(0xFFA0401C)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The daily projection strip: one bar per day of the plan.
class PlanDayStrip extends StatelessWidget {
  const PlanDayStrip({super.key, required this.allocations});

  final List<DailyAllocation> allocations;

  @override
  Widget build(BuildContext context) {
    final byDay = <int, num>{};
    for (final item in allocations) {
      byDay[item.dayIndex] = (byDay[item.dayIndex] ?? 0) + item.amount;
    }
    if (byDay.isEmpty) {
      return const SizedBox.shrink();
    }
    final days = byDay.keys.toList()..sort();
    final highest = byDay.values.fold<num>(0, (max, value) {
      return value > max ? value : max;
    });
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final day = days[index];
          final amount = byDay[day] ?? 0;
          final ratio = highest <= 0 ? 0.0 : (amount / highest).toDouble();
          return Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Ngày $day',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: ratio <= 0 ? 0.05 : ratio,
                      child: Container(
                        decoration: BoxDecoration(
                          color: EnvelopeStyle.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
