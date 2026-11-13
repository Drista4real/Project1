import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/plan/widgets/plan_widgets.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

/// One day of a plan: the engine's limit and the recorded spending.
class PlanDay {
  const PlanDay({
    required this.date,
    required this.dayIndex,
    required this.limit,
    required this.spent,
    required this.groups,
  });

  final DateTime date;
  final int dayIndex;
  final num limit;
  final num spent;
  final List<DailyAllocation> groups;

  bool get overLimit => spent > limit;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// The days of [plan], keyed by date, from its allocation rows.
///
/// Every figure is the engine's: the limit is the sum of the day's group
/// allocations and the spending is their recorded `actual_spent`.
Map<DateTime, PlanDay> planDays(
  BudgetPlan plan,
  List<DailyAllocation> allocations,
) {
  final start = plan.startDate == null ? null : _dateOnly(plan.startDate!);
  final rows = <DateTime, List<DailyAllocation>>{};
  final indexes = <DateTime, int>{};
  for (final item in allocations) {
    final date = item.allocDate != null
        ? _dateOnly(item.allocDate!)
        : start?.add(Duration(days: item.dayIndex - 1));
    if (date == null) continue;
    rows.putIfAbsent(date, () => []).add(item);
    indexes[date] = item.dayIndex;
  }
  return {
    for (final entry in rows.entries)
      entry.key: PlanDay(
        date: entry.key,
        dayIndex: indexes[entry.key] ?? 0,
        limit: entry.value.fold<num>(0, (sum, item) => sum + item.amount),
        spent: entry.value.fold<num>(0, (sum, item) => sum + item.actualSpent),
        groups: entry.value,
      ),
  };
}

/// `152k`, `1,2tr`: an amount short enough for a calendar cell.
String formatCompactVnd(num amount) {
  final value = amount.abs();
  if (value == 0) return '0đ';
  if (value < 1000) return '${value.round()}đ';
  if (value < 1000000) return '${(value / 1000).round()}k';
  final millions = (value / 1000000).toStringAsFixed(1);
  return '${millions.endsWith('.0') ? millions.substring(0, millions.length - 2) : millions.replaceAll('.', ',')}tr';
}

String _dayMonth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}';

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

/// The summary above the calendar: today's room and the whole plan's.
class PlanTodayCard extends StatelessWidget {
  const PlanTodayCard({
    super.key,
    required this.plan,
    required this.today,
    required this.days,
  });

  final BudgetPlan plan;
  final DateTime today;
  final Map<DateTime, PlanDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final todayDay = days[_dateOnly(today)];
    final totalSpent = days.values.fold<num>(0, (sum, day) => sum + day.spent);
    final start = plan.startDate;
    final end = start?.add(Duration(days: plan.durationDays - 1));
    final period = start == null || end == null
        ? '${plan.durationDays} NGÀY'
        : '${_dayMonth(start)} – ${_dayMonth(end)}';
    final dayLabel = todayDay == null
        ? ''
        : ' · NGÀY ${todayDay.dayIndex}/${plan.durationDays}';
    // Both operands are the engine's figures; the screen only compares them.
    final left = plan.spendableBudget - totalSpent;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, size: 16, color: onPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$period$dayLabel',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: onPrimary.withAlpha(38),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  left >= 0
                      ? 'Còn ${formatVnd(left)}'
                      : 'Vượt ${formatVnd(left)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (todayDay != null)
            ..._todayFigures(theme, onPrimary, todayDay)
          else ...[
            Text(
              formatVnd(plan.dailyAllowance),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Hạn mức mỗi ngày · hôm nay nằm ngoài kỳ kế hoạch',
              style: theme.textTheme.bodySmall?.copyWith(color: onPrimary),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _todayFigures(ThemeData theme, Color onPrimary, PlanDay day) {
    final room = day.limit - day.spent;
    final progress = day.limit <= 0
        ? 0.0
        : (day.spent / day.limit).clamp(0.0, 1.0).toDouble();
    return [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 10,
        children: [
          Text(
            formatVnd(room),
            key: const ValueKey('plan-today-left'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: room < 0 ? const Color(0xFFFFC4AE) : onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              room < 0 ? 'hôm nay đã vượt' : 'hôm nay còn được chi',
              style: theme.textTheme.bodySmall?.copyWith(color: onPrimary),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: onPrimary.withAlpha(64),
          color: day.overLimit ? AppTheme.expenseCoral : AppTheme.secondaryMint,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Đã chi ${formatVnd(day.spent)} / hạn mức ${formatVnd(day.limit)}',
        style: theme.textTheme.bodySmall?.copyWith(color: onPrimary),
      ),
    ];
  }
}

/// The month grid of a plan, laid out like the ledger calendar.
class PlanCalendar extends StatelessWidget {
  const PlanCalendar({
    super.key,
    required this.month,
    required this.days,
    required this.today,
    required this.selected,
    required this.onSelect,
    required this.onMoveMonth,
    required this.canGoBack,
    required this.canGoForward,
  });

  final DateTime month;
  final Map<DateTime, PlanDay> days;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onMoveMonth;
  final bool canGoBack;
  final bool canGoForward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingDays = firstDay.weekday - 1;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Tháng trước',
                onPressed: canGoBack ? () => onMoveMonth(-1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Tháng ${month.month}, ${month.year}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tháng sau',
                onPressed: canGoForward ? () => onMoveMonth(1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final day in const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: day == 'CN'
                            ? AppTheme.expenseCoral
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < totalCells ~/ 7; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: _buildCell(
                        context,
                        row * 7 + column - leadingDays + 1,
                        daysInMonth,
                        column == 6,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _legend(context, AppTheme.incomeEmerald, 'Trong hạn mức'),
              _legend(context, AppTheme.expenseCoral, 'Vượt hạn mức'),
              _legend(context, scheme.outline, 'Dự kiến'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );

  Widget _buildCell(
    BuildContext context,
    int dayNumber,
    int daysInMonth,
    bool sunday,
  ) {
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 50);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = DateTime(month.year, month.month, dayNumber);
    final day = days[date];
    final isToday = date == _dateOnly(today);
    final isPast = date.isBefore(_dateOnly(today));
    final isSelected = selected != null && date == _dateOnly(selected!);

    if (day == null) {
      return SizedBox(
        height: 50,
        child: Center(
          child: Text(
            '$dayNumber',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant.withAlpha(110),
            ),
          ),
        ),
      );
    }

    // A day with spending shows it, even ahead of today.
    final recorded = isPast || isToday || day.spent > 0;
    final Color fill;
    final Color amountColor;
    if (isToday) {
      fill = scheme.primaryContainer;
      amountColor = scheme.primary;
    } else if (recorded) {
      final tone = day.overLimit
          ? AppTheme.expenseCoral
          : AppTheme.incomeEmerald;
      fill = tone.withAlpha(36);
      amountColor = tone;
    } else {
      fill = Colors.transparent;
      amountColor = scheme.outline;
    }
    final amount = recorded ? day.spent : day.limit;
    final status = recorded
        ? 'đã chi ${formatVnd(day.spent)}, hạn mức ${formatVnd(day.limit)}'
        : 'hạn mức dự kiến ${formatVnd(day.limit)}';
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Ngày ${_dayMonth(date)}, $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isToday
                ? BorderSide(color: scheme.primary, width: 2)
                : isSelected
                ? BorderSide(color: scheme.outline)
                : BorderSide.none,
          ),
          child: InkWell(
            key: ValueKey('plan-day-${_dayMonth(date)}'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(date),
            child: SizedBox(
              height: 50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$dayNumber',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      color: isToday
                          ? scheme.primary
                          : sunday && !recorded
                          ? AppTheme.expenseCoral
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatCompactVnd(amount),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: recorded
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: amountColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected day: its spending against the limit, group by group.
class PlanDayDetail extends StatelessWidget {
  const PlanDayDetail({super.key, required this.day, required this.today});

  final PlanDay day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isToday = day.date == _dateOnly(today);
    final future = day.date.isAfter(_dateOnly(today)) && day.spent <= 0;
    final title =
        '${_weekdays[day.date.weekday - 1]}, ${_dayMonth(day.date)}'
        '${isToday ? ' · Hôm nay' : ''}';
    return Container(
      key: const ValueKey('plan-day-detail'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                future
                    ? 'Dự kiến ${formatVnd(day.limit)}'
                    : '${formatVnd(day.spent)} / ${formatVnd(day.limit)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: day.overLimit && !future
                      ? AppTheme.expenseCoral
                      : scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final group in day.groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      planGroupIcons[group.groupKey] ?? Icons.circle_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      planGroupLabels[group.groupKey] ?? group.groupKey,
                    ),
                  ),
                  Text(
                    future
                        ? formatVnd(group.amount)
                        : '${formatVnd(group.actualSpent)} / '
                              '${formatVnd(group.amount)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: !future && group.actualSpent > group.amount
                          ? AppTheme.expenseCoral
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
