import '../entities/financial_overview.dart';
import '../repositories/finance_repository.dart';

class GetFinancialOverview {
  final FinanceRepository repository;

  const GetFinancialOverview(this.repository);

  Future<FinancialOverview> call() => repository.getOverview();
}
