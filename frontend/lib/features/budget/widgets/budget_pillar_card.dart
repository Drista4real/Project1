import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/budget_month_overview.dart';
import '../models/envelope_pillar.dart';
import 'budget_category_limit_row.dart';

class BudgetPillarCard extends StatelessWidget {
  const BudgetPillarCard({
    super.key,
    required this.overview,
    required this.pillar,
    required this.onEdit,
  });
  final BudgetMonthOverview overview;
  final EnvelopePillar pillar;
  final ValueChanged<FinanceRecord> onEdit;
  @override
  Widget build(BuildContext context) {
    final limit = overview.envelopes.allocation(pillar);
    final used = overview.spentFor(pillar);
    final progress = limit <= 0 ? 0.0 : used / limit;
    final direct = overview.envelopes.budgetFor(pillar: pillar.key);
    final threshold = financeAmount(direct?['alert_threshold_percent'] ?? 80);
    final warning = limit > 0 && progress * 100 >= threshold;
    final records = overview.categoryBudgets(pillar);
    final remaining = limit - used;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EnvelopeStyle.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: pillar.tint,
                child: Text(
                  '${pillar.index + 1}',
                  style: TextStyle(fontSize: 12, color: pillar.color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pillar.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: pillar.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                overview.envelopes.suggested
                    ? 'Chưa\nphân bổ'
                    : '${overview.envelopes.percent(pillar).toStringAsFixed(1).replaceAll('.0', '')}%\nphân bổ',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10, color: pillar.color),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric('Đã chi', formatVnd(used), EnvelopeStyle.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  direct != null
                      ? 'Hạn mức trụ cột'
                      : records.isNotEmpty && limit > 0
                      ? 'Tổng hạn mức danh mục'
                      : 'Hạn mức',
                  limit <= 0 ? 'Chưa đặt' : formatVnd(limit),
                  pillar.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 7,
              color: warning ? EnvelopePillar.wants.barColor : pillar.barColor,
              backgroundColor: pillar.tint,
              semanticsLabel: 'Mức sử dụng ${pillar.title}',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            limit <= 0
                ? 'Chưa cấp hạn mức cho trụ cột này.'
                : remaining < 0
                ? 'Vượt ${formatVnd(-remaining)} · ${(progress * 100).toStringAsFixed(1)}% đã dùng'
                : 'Còn ${formatVnd(remaining)} · ${(progress * 100).toStringAsFixed(1)}% đã dùng',
            style: TextStyle(
              fontSize: 11,
              color: warning ? EnvelopePillar.wants.color : EnvelopeStyle.muted,
            ),
          ),
          if (warning)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: EnvelopePillar.wants.tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  progress >= 1
                      ? 'Đã chạm hoặc vượt hạn mức phong bao.'
                      : 'Đã tới ngưỡng cảnh báo ${threshold.toStringAsFixed(0)}%.',
                  style: TextStyle(
                    fontSize: 11,
                    color: EnvelopePillar.wants.color,
                  ),
                ),
              ),
            ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Chưa có hạn mức riêng cho danh mục.',
                style: TextStyle(fontSize: 11, color: EnvelopeStyle.muted),
              ),
            )
          else
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: PageStorageKey(
                  'budget-${overview.envelopes.monthKey}-${pillar.key}',
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  '${records.length} hạn mức danh mục',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EnvelopeStyle.muted,
                  ),
                ),
                children: [
                  for (final record in records)
                    BudgetCategoryLimitRow(
                      title: overview.data.title(record),
                      used: overview.data.used(record, overview.month),
                      record: record,
                      pillar: pillar,
                      onEdit: () => onEdit(record),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: EnvelopeStyle.muted),
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    ],
  );
}
