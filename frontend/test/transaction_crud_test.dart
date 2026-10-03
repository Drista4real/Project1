import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/dashboard/presentation/screens/quick_add_transaction_screen.dart';
import 'package:project_one/features/dashboard/presentation/screens/transaction_detail_screen.dart';
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

Future<void> open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screen),
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create uses selected wallet and validates amount', (
    tester,
  ) async {
    final repository = FakeFinanceRepository();
    await open(tester, QuickAddTransactionScreen(repository: repository));
    await tester.enterText(
      find.byKey(const ValueKey('transactionAmount')),
      '0',
    );
    await tester.scrollUntilVisible(
      find.text('Lưu giao dịch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(repository.added, isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('transactionAmount')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('transactionAmount')),
      '45.000,50',
    );
    await tester.scrollUntilVisible(
      find.text('Lưu giao dịch'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Lưu giao dịch'));
    await tester.pumpAndSettle();
    expect(repository.added?['amount'], 45000.5);
    expect(repository.added?['account_id'], 1);
  });

  testWidgets(
    'edit preserves decimal amount and clears category when changing type',
    (tester) async {
      final repository = FakeFinanceRepository();
      await open(
        tester,
        QuickAddTransactionScreen(
          repository: repository,
          transaction: repository.transaction,
        ),
      );
      expect(find.text('Sửa giao dịch'), findsOneWidget);
      expect(find.text('45000,25'), findsOneWidget);
      await tester.ensureVisible(find.text('Thu nhập'));
      await tester.tap(find.text('Thu nhập'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Lưu giao dịch'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pumpAndSettle();
      expect(repository.updated?['amount'], '45000.25');
      expect(repository.updated?['transaction_type'], 'income');
      expect(repository.updated?['category_id'], isNull);
    },
  );

  testWidgets('delete requires confirmation and cancel keeps record', (
    tester,
  ) async {
    final repository = FakeFinanceRepository();
    await open(
      tester,
      TransactionDetailScreen(transactionId: 7, repository: repository),
    );
    expect(find.text('Cà phê'), findsOneWidget);
    await tester.tap(find.text('Xóa giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isFalse);
    await tester.tap(find.text('Xóa giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isTrue);
  });
}
