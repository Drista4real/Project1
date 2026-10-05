import 'package:project_one/features/finance/domain/entities/account.dart';
import 'package:project_one/features/finance/domain/entities/category.dart';
import 'package:project_one/features/finance/domain/entities/financial_overview.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/finance/domain/repositories/finance_repository.dart';

class FakeFinanceRepository implements FinanceRepository {
  final double balance;
  FakeFinanceRepository({this.balance = 0});
  final transaction = Transaction(
    id: 7,
    userId: 'user',
    accountId: 1,
    categoryId: 1,
    amount: 45000.25,
    transactionType: 'expense',
    rawDescription: 'Cà phê',
    transactionDate: DateTime(2026, 10, 3),
    createdAt: DateTime(2026, 10, 3),
    categoryName: 'Ăn uống',
  );
  Map<String, dynamic>? added;
  Map<String, dynamic>? updated;
  bool deleted = false;
  @override
  Future<List<Account>> getAccounts() async => [
    const Account(id: 1, name: 'Tiền mặt'),
  ];
  @override
  Future<List<Category>> getCategories() async => [
    const Category(id: 1, name: 'Ăn uống', isIncome: false),
    const Category(id: 2, name: 'Lương', isIncome: true),
  ];
  @override
  Future<Transaction> getTransaction(int id) async => transaction;
  @override
  Future<void> addTransaction({
    required double amount,
    required String transactionType,
    required String description,
    int? categoryId,
    String? categoryName,
    int? accountId,
    DateTime? transactionDate,
  }) async {
    added = {
      'amount': amount,
      'account_id': accountId,
      'transaction_type': transactionType,
      'description': description,
    };
  }

  @override
  Future<void> updateTransaction(int id, Map<String, dynamic> changes) async {
    updated = changes;
  }

  @override
  Future<void> deleteTransaction(int id) async {
    deleted = true;
  }

  @override
  Future<FinancialOverview> getOverview() async => FinancialOverview(
    currentBalance: balance,
    monthlyIncome: 0,
    monthlyExpense: 0,
  );
  @override
  Future<List<Transaction>> getTransactions() async => [transaction];
}
