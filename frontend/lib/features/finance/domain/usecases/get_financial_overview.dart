import 'package:project_one/features/finance/domain/entities/financial_overview.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';

class GetFinancialOverview {
  final FinanceRepository repository;

  const GetFinancialOverview(this.repository);

  Future<FinancialOverview> call() => repository.getOverview();
}
