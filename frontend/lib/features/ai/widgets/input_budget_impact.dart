import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3EE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.spa_outlined,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tác động phong bao Kakeibo',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Các khoản chi đang chọn: ${formatVnd(total)}. Số dư và ngân sách sẽ cập nhật sau khi bạn xác nhận.',
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                    if (touched.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        loadFailed
                            ? 'Chưa tải được ngân sách để đối chiếu.'
                            : 'Chưa có ngân sách tương ứng để đối chiếu.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                    for (final budget in touched.take(4)) ...[
                      const SizedBox(height: 8),
                      Builder(
                        builder: (_) {
                          final remaining =
                              financeAmount(budget['limit_amount']) -
                              data!.used(budget, month) -
                              pendingForBudget(data!, budget, drafts, month);
                          return Text(
                            '${data!.title(budget)}: ${remaining < 0 ? 'dự kiến vượt' : 'dự kiến còn'} ${formatVnd(remaining)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: remaining < 0
                                  ? AppTheme.expenseCoral
                                  : AppTheme.primaryForestGreen,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (limit != null && limit > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: ((spent + pending) / limit).clamp(0, 1),
                          backgroundColor: AppTheme.lightMintBg,
                          strokeWidth: 4,
                        ),
                      ),
                      Text(
                        '${((spent + pending) / limit * 100).round()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ngân sách tháng này',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dự kiến ${formatVnd(spent + pending)} / ${formatVnd(limit)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
