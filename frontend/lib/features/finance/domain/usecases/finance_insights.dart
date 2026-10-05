import 'package:project_one/features/finance/domain/repositories/management_repository.dart';

typedef FinanceRecord = Map<String, dynamic>;

double financeAmount(Object? value) => double.tryParse('$value') ?? 0;

DateTime? financeDate(Object? value) => DateTime.tryParse('$value')?.toLocal();

const pillarNames = {
  'needs': 'Thiết yếu (Needs)',
  'wants': 'Mong muốn (Wants)',
  'culture': 'Văn hóa (Culture)',
  'unexpected': 'Dự phòng (Extra)',
  'income': 'Thu nhập',
};

class FinanceInsights {
  const FinanceInsights(this.repository);
  final ManagementRepository repository;

  Future<SpendingData> spending() async {
    final results = await Future.wait([
      repository.references('transactions'),
      repository.references('categories'),
    ]);
    return SpendingData(results[0], results[1]);
  }

  Future<BudgetData> budgets() async {
    final results = await Future.wait([
      spending(),
      repository.references('budgets'),
    ]);
    return BudgetData(
      results[0] as SpendingData,
      results[1] as List<FinanceRecord>,
    );
  }

  Future<ForecastData> forecasts() async {
    final results = await Future.wait([
      repository.get('profile', 'me'),
      repository.references('cashflow_forecasts'),
      repository.references('cashflow_alerts'),
      repository.references('ai_consultations'),
    ]);
    return ForecastData(
      results[0] as FinanceRecord,
      results[1] as List<FinanceRecord>,
      results[2] as List<FinanceRecord>,
      results[3] as List<FinanceRecord>,
    );
  }
}

class SpendingData {
  SpendingData(this.transactions, List<FinanceRecord> categories)
    : categories = {
        for (final category in categories) category['id'] as int: category,
      };
  final List<FinanceRecord> transactions;
  final Map<int, FinanceRecord> categories;

  List<FinanceRecord> between(DateTime start, DateTime end) =>
      transactions.where((item) {
        final date = financeDate(item['transaction_date']);
        return date != null && !date.isBefore(start) && date.isBefore(end);
      }).toList();

  List<FinanceRecord> month(DateTime month) => between(
    DateTime(month.year, month.month),
    DateTime(month.year, month.month + 1),
  );

  double total(Iterable<FinanceRecord> items, String type) => items
      .where((item) => item['transaction_type'] == type)
      .fold(0.0, (sum, item) => sum + financeAmount(item['amount']));

  String? pillar(FinanceRecord transaction) =>
      transaction['pillar'] as String? ??
      categories[transaction['category_id']]?['pillar'] as String?;

  List<CategorySpend> distribution(List<FinanceRecord> items) {
    final totals = <int?, double>{};
    for (final item in items.where(
      (item) => item['transaction_type'] == 'expense',
    )) {
      final id = item['category_id'] as int?;
      totals[id] = (totals[id] ?? 0) + financeAmount(item['amount']);
    }
    final result = totals.entries
        .map(
          (entry) => CategorySpend(
            categories[entry.key]?['name'] as String? ?? 'Chưa phân loại',
            entry.value,
            categories[entry.key]?['color'] as String? ?? '#7B8782',
          ),
        )
        .toList();
    result.sort((a, b) => b.amount.compareTo(a.amount));
    return result;
  }

  List<double> week(DateTime anchor) {
    final start = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday + 1,
    );
    return List.generate(
      7,
      (index) => total(
        between(
          DateTime(start.year, start.month, start.day + index),
          DateTime(start.year, start.month, start.day + index + 1),
        ),
        'expense',
      ),
    );
  }
}

class CategorySpend {
  const CategorySpend(this.name, this.amount, this.color);
  final String name;
  final double amount;
  final String color;
}

class BudgetData {
  const BudgetData(this.spending, this.records);
  final SpendingData spending;
  final List<FinanceRecord> records;

  List<FinanceRecord> month(DateTime month) => records.where((record) {
    final date = financeDate(record['month_year']);
    return date?.year == month.year && date?.month == month.month;
  }).toList();

  double used(FinanceRecord budget, DateTime month) => spending.total(
    spending.month(month).where((item) {
      if (budget['category_id'] != null) {
        return item['category_id'] == budget['category_id'];
      }
      if (budget['pillar'] != null) {
        return spending.pillar(item) == budget['pillar'];
      }
      return true;
    }),
    'expense',
  );

  String title(FinanceRecord budget) => budget['category_id'] != null
      ? (spending.categories[budget['category_id']]?['name'] as String? ??
            'Danh mục #${budget['category_id']}')
      : pillarNames[budget['pillar']] ?? 'Ngân sách tổng';

  /// A total budget takes precedence; category and pillar budgets may overlap.
  double? totalLimit(DateTime month) {
    final overall = this
        .month(month)
        .where((item) => item['category_id'] == null && item['pillar'] == null)
        .toList();
    if (overall.isEmpty) return null;
    overall.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return financeAmount(overall.first['limit_amount']);
  }
}

class ForecastData {
  const ForecastData(
    this.profile,
    this.records,
    this.alerts,
    this.consultations,
  );
  final FinanceRecord profile;
  final List<FinanceRecord> records;
  final List<FinanceRecord> alerts;
  final List<FinanceRecord> consultations;

  List<FinanceRecord> upcoming(DateTime today, int days) {
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(start.year, start.month, start.day + days + 1);
    // Multiple models may predict the same date. Display the newest saved record.
    final byDate = <String, FinanceRecord>{};
    for (final record in records) {
      final date = financeDate(record['forecast_date']);
      if (date == null || date.isBefore(start) || !date.isBefore(end)) continue;
      final key = '${date.year}-${date.month}-${date.day}';
      if (!byDate.containsKey(key) ||
          (record['id'] as int) > (byDate[key]!['id'] as int)) {
        byDate[key] = record;
      }
    }
    final result = byDate.values.toList();
    result.sort(
      (a, b) => financeDate(
        a['forecast_date'],
      )!.compareTo(financeDate(b['forecast_date'])!),
    );
    return result;
  }
}
