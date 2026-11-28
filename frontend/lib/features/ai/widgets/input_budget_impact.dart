import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/transaction_draft.dart';

double pendingForBudget(
  BudgetData data,
  FinanceRecord budget,
  List<ReviewTransaction> drafts,
  DateTime month,
) => drafts
    .where((draft) {
      if (draft.type != 'expense' ||
          draft.date.year != month.year ||
          draft.date.month != month.month) {
        return false;
      }
      if (budget['category_id'] != null) {
        return draft.categoryId == budget['category_id'];
      }
      if (budget['pillar'] != null) {
        return data.spending.categories[draft.categoryId]?['pillar'] ==
            budget['pillar'];
      }
      return true;
    })
    .fold(0.0, (total, draft) => total + (draft.amount ?? 0));

class InputBudgetImpact extends StatelessWidget {
  const InputBudgetImpact({
    required this.drafts,
    this.data,
    this.loadFailed = false,
    super.key,
  });
  final List<ReviewTransaction> drafts;
  final BudgetData? data;
  final bool loadFailed;

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now();
    final expenses = drafts.where((draft) => draft.type == 'expense').toList();
    final total = expenses.fold(0.0, (sum, draft) => sum + (draft.amount ?? 0));
    final budgets = data?.month(month) ?? [];
    final touched = budgets
        .where((budget) => pendingForBudget(data!, budget, drafts, month) > 0)
        .toList();
    final limit = data?.totalLimit(month);
    final spent =
        data?.spending.total(data!.spending.month(month), 'expense') ?? 0;
    final pending = drafts
        .where(
          (draft) =>
              draft.type == 'expense' &&
              draft.date.year == month.year &&
              draft.date.month == month.month,
        )
        .fold(0.0, (sum, draft) => sum + (draft.amount ?? 0));
    final colors = Theme.of(context).colorScheme;
    final income = drafts
        .where((draft) => draft.type == 'income')
        .fold(0.0, (sum, draft) => sum + (draft.amount ?? 0));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expenses.isNotEmpty)
            Text(
              'Tổng chi: ${formatVnd(total)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          if (income > 0) ...[
            if (expenses.isNotEmpty) const SizedBox(height: 6),
            Text(
              'Tổng thu: ${formatVnd(income)}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (touched.isEmpty)
              Text(
                loadFailed
                    ? 'Chưa tải được ngân sách.'
                    : data == null
                    ? 'Đang tải ngân sách…'
                    : 'Chưa có ngân sách cho khoản chi này.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            for (final budget in touched.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Builder(
                  builder: (_) {
                    final remaining =
                        financeAmount(budget['limit_amount']) -
                        data!.used(budget, month) -
                        pendingForBudget(data!, budget, drafts, month);
                    return Text(
                      '${data!.title(budget)}: ${remaining < 0 ? 'sẽ vượt' : 'sẽ còn'} ${formatVnd(remaining.abs())}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: remaining < 0
                            ? colors.error
                            : colors.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            if (limit != null && limit > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Ngân sách tháng này sau khi lưu',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: ((spent + pending) / limit).clamp(0, 1),
                color: spent + pending > limit ? colors.error : colors.primary,
                backgroundColor: colors.surfaceContainerHighest,
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatVnd(spent + pending)} / ${formatVnd(limit)}',
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
