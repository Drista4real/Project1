import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/budget_month_overview.dart';
import '../models/envelope_pillar.dart';
import 'envelope_banner.dart';
import 'budget_summary_card.dart';
import 'budget_pillar_card.dart';
import 'budget_category_limit_row.dart';

class BudgetOverviewContent extends StatelessWidget {
  const BudgetOverviewContent({
    super.key,
    required this.overview,
    required this.onMonth,
    required this.onManage,
    required this.onRebalance,
    required this.onSavingGoals,
    required this.onEdit,
    required this.onAdvanced,
  });
  final BudgetMonthOverview overview;
  final ValueChanged<int> onMonth;
  final VoidCallback onManage, onRebalance, onSavingGoals, onAdvanced;
  final ValueChanged<FinanceRecord> onEdit;
  @override
  Widget build(BuildContext context) {
    final other = overview.categoryBudgets(null);
    final unassigned = overview.spentFor(null);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EnvelopeBanner(
              eyebrow: 'NGÂN SÁCH KAKEIBO',
              title: 'Chi tiêu cân bằng mỗi tháng',
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ngân sách tháng ${overview.month.month}/${overview.month.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: EnvelopeStyle.muted,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tháng trước',
                  onPressed: () => onMonth(-1),
                  icon: const Icon(Icons.chevron_left, size: 22),
                ),
                IconButton(
                  tooltip: 'Tháng sau',
                  onPressed: () => onMonth(1),
                  icon: const Icon(Icons.chevron_right, size: 22),
                ),
              ],
            ),
            BudgetSummaryCard(overview: overview),
            if (overview.daily != null) ...[
              const SizedBox(height: 12),
              BudgetDailyAllowance(overview: overview),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.category_outlined, size: 19),
                label: const Text('Quản lý danh mục & phong bao'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRebalance,
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(
                      overview.limit == null
                          ? 'Thiết lập ngân sách'
                          : 'Điều chỉnh phân bổ',
                      textAlign: TextAlign.center,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSavingGoals,
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: const Text(
                      'Mục tiêu tiết kiệm',
                      textAlign: TextAlign.center,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '4 phong bao Kakeibo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: EnvelopeStyle.primary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Theo dõi chi tiêu từng trụ cột, mở rộng để xem hạn mức danh mục.',
              style: TextStyle(
                fontSize: 12,
                color: EnvelopeStyle.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            for (final pillar in EnvelopePillar.values)
              BudgetPillarCard(
                overview: overview,
                pillar: pillar,
                onEdit: onEdit,
              ),
            if (unassigned > 0 || other.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: EnvelopeStyle.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chưa phân trụ cột',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Đã chi ${formatVnd(unassigned)} · Chọn trụ cột trong phần quản lý danh mục.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: EnvelopeStyle.muted,
                        height: 1.5,
                      ),
                    ),
                    for (final record in other)
                      BudgetCategoryLimitRow(
                        title: overview.data.title(record),
                        used: overview.data.used(record, overview.month),
                        record: record,
                        onEdit: () => onEdit(record),
                      ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: onAdvanced,
              icon: const Icon(Icons.tune, size: 17),
              label: const Text(
                'Hạn mức tổng & cảnh báo nâng cao',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
