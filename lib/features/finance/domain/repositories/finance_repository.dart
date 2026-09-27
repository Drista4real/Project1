import '../entities/category.dart';
import '../entities/financial_overview.dart';
import '../entities/transaction.dart';

abstract interface class FinanceRepository {
  Future<FinancialOverview> getOverview();
  Future<List<Transaction>> getTransactions();
  Future<List<Category>> getCategories();
  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
  });
}
