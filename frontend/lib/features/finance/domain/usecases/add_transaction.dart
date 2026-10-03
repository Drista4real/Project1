import '../repositories/finance_repository.dart';

class AddTransaction {
  final FinanceRepository repository;

  const AddTransaction(this.repository);

  Future<void> call({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
    int? accountId,
    DateTime? transactionDate,
  }) {
    return repository.addTransaction(
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
