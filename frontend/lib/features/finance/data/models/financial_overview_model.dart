import 'package:project_one/features/finance/domain/entities/financial_overview.dart';

class FinancialOverviewModel extends FinancialOverview {
  const FinancialOverviewModel({
    required super.currentBalance,
    required super.monthlyIncome,
    required super.monthlyExpense,
  });
}
