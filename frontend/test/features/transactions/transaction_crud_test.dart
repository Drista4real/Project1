import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import '../../helpers/fake_finance_repository.dart';
import 'package:project_one/features/transactions/screens/quick_add_transaction_screen.dart';
import 'package:project_one/features/transactions/screens/transaction_detail_screen.dart';

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
