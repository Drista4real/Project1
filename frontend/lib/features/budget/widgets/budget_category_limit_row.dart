import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/envelope_pillar.dart';

class BudgetCategoryLimitRow extends StatelessWidget {
  const BudgetCategoryLimitRow({
    super.key,
    required this.title,
    required this.used,
    required this.record,
    required this.onEdit,
    this.pillar,
  });
  final String title;
  final double used;
  final FinanceRecord record;
  final VoidCallback onEdit;
  final EnvelopePillar? pillar;
  @override
  Widget build(BuildContext context) {
    final limit = financeAmount(record['limit_amount']);
    final threshold = financeAmount(record['alert_threshold_percent'] ?? 80);
    final warning = limit > 0 && used / limit * 100 >= threshold;
    final color = warning
        ? EnvelopePillar.wants.color
        : pillar?.color ?? EnvelopeStyle.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: EnvelopeStyle.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatVnd(used)} / ${formatVnd(limit)}',
                  style: TextStyle(fontSize: 11, color: color),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: limit <= 0 ? 0 : (used / limit).clamp(0, 1),
                    minHeight: 4,
                    color: color,
                    backgroundColor: EnvelopeStyle.soft,
                    semanticsLabel: 'Chi tiêu $title',
                  ),
                ),
                if (warning)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      used >= limit
                          ? 'Vượt hoặc chạm hạn mức danh mục.'
                          : 'Đã tới ngưỡng cảnh báo ${threshold.toStringAsFixed(0)}%.',
                      style: TextStyle(fontSize: 11, color: color),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Chỉnh hạn mức $title',
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              size: 19,
              color: EnvelopeStyle.muted,
            ),
          ),
        ],
      ),
    );
  }
}
