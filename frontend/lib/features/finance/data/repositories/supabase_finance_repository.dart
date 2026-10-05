import 'package:project_one/features/finance/domain/entities/category.dart';
import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/financial_overview.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';
import 'package:project_one/features/finance/data/datasources/finance_remote_data_source.dart';

class SupabaseFinanceRepository implements FinanceRepository {
  final FinanceRemoteDataSource remoteDataSource;

  const SupabaseFinanceRepository(this.remoteDataSource);

  @override
  Future<FinancialOverview> getOverview() => remoteDataSource.getOverview();

  @override
  Future<List<Transaction>> getTransactions() =>
      remoteDataSource.getTransactions();

  @override
  Future<List<Category>> getCategories() => remoteDataSource.getCategories();

  @override
  Future<List<Account>> getAccounts() => remoteDataSource.getAccounts();

  @override
  Future<Transaction> getTransaction(int id) =>
      remoteDataSource.getTransaction(id);

  @override
  Future<void> updateTransaction(int id, Map<String, dynamic> changes) =>
      remoteDataSource.updateTransaction(id, changes);

  @override
  Future<void> deleteTransaction(int id) =>
      remoteDataSource.deleteTransaction(id);

  @override
  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
    int? accountId,
    DateTime? transactionDate,
  }) {
    return remoteDataSource.addTransaction(
      amount: amount,
      transactionType: transactionType,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
      accountId: accountId,
      transactionDate: transactionDate,
    );
  }
}
