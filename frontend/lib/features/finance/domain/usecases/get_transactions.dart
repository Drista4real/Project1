import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';

class GetTransactions {
  final FinanceRepository repository;

  const GetTransactions(this.repository);

  Future<List<Transaction>> call() => repository.getTransactions();
}
