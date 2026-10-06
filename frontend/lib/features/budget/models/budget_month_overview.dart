import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'category_envelope_data.dart';
import 'envelope_pillar.dart';

class BudgetMonthOverview {
  BudgetMonthOverview(this.data, this.month, {DateTime? today})
    : today = today ?? DateTime.now(),
      envelopes = CategoryEnvelopeData(
        month,
        data.spending.categories.values.toList(),
        data.records,
      );
  final BudgetData data;
  final DateTime month, today;
  final CategoryEnvelopeData envelopes;
  List<FinanceRecord> get expenses => data.spending
      .month(month)
      .where((t) => t['transaction_type'] == 'expense')
      .toList();
  double get spent => data.spending.total(expenses, 'expense');
  double? get limit => data.totalLimit(month);
  double? get remaining => limit == null ? null : limit! - spent;
  double get progress => limit == null || limit! <= 0 ? 0 : spent / limit!;
  bool get current => month.year == today.year && month.month == today.month;
  int get daysLeft =>
      DateTime(month.year, month.month + 1, 0).day - today.day + 1;
  double? get daily => !current || remaining == null
      ? null
      : (remaining! / daysLeft).clamp(0, double.infinity);
  double spentFor(EnvelopePillar? pillar) => data.spending.total(
    expenses.where(
      (t) => EnvelopePillar.fromKey(data.spending.pillar(t)) == pillar,
    ),
    'expense',
  );
  List<FinanceRecord> categoryBudgets(EnvelopePillar? pillar) {
    final latest = <int, FinanceRecord>{};
    for (final b in envelopes.budgets) {
      final id = b['category_id'] as int?;
      if (id != null) latest.putIfAbsent(id, () => b);
    }
    return latest.values
        .where(
          (b) =>
              EnvelopePillar.fromKey(
                data.spending.categories[b['category_id']]?['pillar'],
              ) ==
              pillar,
        )
        .toList();
  }
}
