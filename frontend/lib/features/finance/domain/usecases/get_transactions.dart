import '../entities/transaction.dart';
import '../repositories/finance_repository.dart';

class GetTransactions {
  final FinanceRepository repository;

  const GetTransactions(this.repository);

  Future<List<Transaction>> call() => repository.getTransactions();
}
