import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/data/models/category_model.dart';
import 'package:project_one/features/finance/data/models/financial_overview_model.dart';
import 'package:project_one/features/finance/data/models/transaction_model.dart';

class FinanceRemoteDataSource {
  final BackendClient api;
  FinanceRemoteDataSource({BackendClient? api}) : api = api ?? BackendClient();

  Future<FinancialOverviewModel> getOverview() async {
    final data = await api.request('GET', '/overview') as Map<String, dynamic>;
    return FinancialOverviewModel(
      currentBalance: double.parse('${data['current_balance']}'),
      monthlyIncome: double.parse('${data['monthly_income']}'),
      monthlyExpense: double.parse('${data['monthly_expense']}'),
    );
  }

  Future<List<TransactionModel>> getTransactions() async {
    final transactions = <TransactionModel>[];
    var offset = 0;
    while (true) {
      final page =
          await api.request('GET', '/transactions?limit=100&offset=$offset')
              as Map<String, dynamic>;
      final rows = page['items'] as List<dynamic>;
      transactions.addAll(
        rows.map(
          (row) => TransactionModel.fromJson(row as Map<String, dynamic>),
        ),
      );
      offset += rows.length;
      if (rows.isEmpty || offset >= (page['total'] as int)) break;
    }
    return transactions;
  }

  Future<TransactionModel> getTransaction(int id) async =>
      TransactionModel.fromJson(
        await api.request('GET', '/transactions/$id') as Map<String, dynamic>,
      );

  Future<List<CategoryModel>> getCategories() async {
    final rows = await api.request('GET', '/categories') as List<dynamic>;
    return rows
        .map((row) => CategoryModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Account>> getAccounts() async {
    final rows = await api.request('GET', '/accounts') as List<dynamic>;
    return rows
        .map(
          (row) => Account(id: row['id'] as int, name: row['name'] as String),
        )
        .toList();
  }

  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
    int? accountId,
    DateTime? transactionDate,
  }) async {
    if (accountId == null) {
      final accounts = await getAccounts();
      if (accounts.isEmpty) {
        throw const FinanceApiException('Bạn chưa có ví để ghi giao dịch.');
      }
      accountId = accounts.first.id;
    }
    await api.request(
      'POST',
      '/transactions',
      body: {
        'amount': amount.toStringAsFixed(2),
        'transaction_type': transactionType,
        'raw_description': description,
        'clean_description': description.trim(),
        'category_id': categoryId,
        'account_id': accountId,
        'transaction_date': (transactionDate ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
      },
    );
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> changes) async {
    await api.request('PATCH', '/transactions/$id', body: changes);
  }

  Future<void> deleteTransaction(int id) async {
    await api.request('DELETE', '/transactions/$id');
  }
}
