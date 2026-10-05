import '../entities/category.dart';
import '../entities/account.dart';
import '../entities/financial_overview.dart';
import '../entities/transaction.dart';

abstract interface class FinanceRepository {
  Future<FinancialOverview> getOverview();
  Future<List<Transaction>> getTransactions();
  Future<List<Category>> getCategories();
  Future<List<Account>> getAccounts();
  Future<Transaction> getTransaction(int id);
  Future<void> updateTransaction(int id, Map<String, dynamic> changes);
  Future<void> deleteTransaction(int id);
  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
    int? accountId,
    DateTime? transactionDate,
  });
}
