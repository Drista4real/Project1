import '../../domain/entities/category.dart';
import '../../domain/entities/financial_overview.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_data_source.dart';

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
  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
  }) {
    return remoteDataSource.addTransaction(
      amount: amount,
      transactionType: transactionType,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
    );
  }
}
