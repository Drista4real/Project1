import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'envelope_pillar.dart';

class CategoryEnvelopeData {
  CategoryEnvelopeData(this.month, this.categories, List<FinanceRecord> records)
    : budgets = records.where((record) {
        final date = financeDate(record['month_year']);
        return date?.year == month.year && date?.month == month.month;
      }).toList()..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));

  final DateTime month;
  final List<FinanceRecord> categories, budgets;
  List<FinanceRecord> get expenses =>
      categories.where((c) => c['is_income'] != true).toList();
  List<FinanceRecord> group(EnvelopePillar pillar) =>
      expenses.where((c) => c['pillar'] == pillar.key).toList();
  List<FinanceRecord> get unassigned => expenses
      .where((c) => EnvelopePillar.fromKey(c['pillar']) == null)
      .toList();

  FinanceRecord? budgetFor({int? categoryId, String? pillar}) {
    for (final budget in budgets) {
      if (budget['category_id'] == categoryId && budget['pillar'] == pillar) {
        return budget;
      }
    }
    return null;
  }

  double allocation(EnvelopePillar pillar) {
    final direct = budgetFor(pillar: pillar.key);
    if (direct != null) return financeAmount(direct['limit_amount']);
    // Once pillar envelopes are configured, a missing pillar is a zero share.
    // Category limits remain independent and must not inflate the allocation.
    if (budgets.any(
      (b) =>
          b['category_id'] == null &&
          EnvelopePillar.fromKey(b['pillar']) != null,
    )) {
      return 0;
    }
    return group(pillar).fold(
      0.0,
      (sum, c) =>
          sum +
          financeAmount(budgetFor(categoryId: c['id'] as int)?['limit_amount']),
    );
  }

  double get allocated =>
      EnvelopePillar.values.fold(0.0, (sum, p) => sum + allocation(p));
  bool get suggested => allocated == 0;
  double percent(EnvelopePillar pillar) => suggested
      ? pillar.suggestedPercent.toDouble()
      : allocation(pillar) / allocated * 100;
  double get totalLimit => financeAmount(budgetFor()?['limit_amount']);
  List<int> get roundedPercentages {
    final shares = EnvelopePillar.values.map(percent).toList();
    final result = shares.map((share) => share.floor()).toList();
    final order = List.generate(
      4,
      (i) => i,
    )..sort((a, b) => (shares[b] - result[b]).compareTo(shares[a] - result[a]));
    final remaining = 100 - result.fold(0, (a, b) => a + b);
    for (var i = 0; i < remaining; i++) {
      result[order[i % 4]]++;
    }
    return result;
  }

  String get monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}-01';
}
