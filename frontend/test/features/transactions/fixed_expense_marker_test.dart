import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/finance/domain/entities/transaction.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';
import 'package:project_one/features/transactions/screens/quick_add_transaction_screen.dart';

import '../../helpers/fake_finance_repository.dart';
import '../onboarding/fake_setup_repository.dart';
import 'transaction_crud_test.dart' show open;

final _plan = BudgetPlan(
  id: 42,
  title: 'Kế hoạch tháng',
  status: 'ACTIVE',
  totalIncome: 8000000,
  durationDays: 30,
  savingsTarget: 0,
  fixedExpenses: 3100000,
  startDate: DateTime(2026, 11, 1),
  spendableBudget: 4900000,
  dailyAllowance: 163333.33,
  survivalFloor: 103333.33,
  planVersion: 1,
  configVersion: 'budget-engine-v1',
  groups: const [],
);

final _marker = find.byKey(const ValueKey('fixedExpenseMarker'));
final _suggestion = find.byKey(const ValueKey('fixedExpenseSuggestion'));

bool _isOn(WidgetTester tester) =>
    tester.widget<SwitchListTile>(_marker).value;

Future<void> _openForm(
  WidgetTester tester,
  FakeFinanceRepository repository, {
  List<BudgetPlan>? plans,
  Transaction? transaction,
}) => open(
  tester,
  QuickAddTransactionScreen(
    repository: repository,
    planRepository: FakeSetupRepository(existingPlans: plans ?? [_plan]),
    transaction: transaction,
  ),
);

Future<void> _save(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('transactionAmount')),
    '2.500.000',
  );
  await tester.scrollUntilVisible(
    find.text('Lưu giao dịch'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Lưu giao dịch'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the fixed expense marker is off by default', (tester) async {
    final repository = FakeFinanceRepository();
    await _openForm(tester, repository);
    await tester.ensureVisible(_marker);
    expect(_isOn(tester), isFalse);
    expect(find.text('Chi phí cố định của kế hoạch'), findsOneWidget);

    await _save(tester);
    expect(repository.added?['fixed_expense_plan_id'], isNull);
  });

  testWidgets('a matching recurring item only suggests the marker', (
    tester,
  ) async {
    final repository = FakeFinanceRepository();
    await _openForm(tester, repository);
    expect(_suggestion, findsNothing);
    await tester.enterText(find.byType(TextFormField).last, 'Tiền nhà');
    await tester.pumpAndSettle();
    await tester.ensureVisible(_marker);
    expect(_suggestion, findsOneWidget);
    expect(_isOn(tester), isFalse);

    await tester.tap(_marker);
    await tester.pumpAndSettle();
    expect(_isOn(tester), isTrue);
    expect(_suggestion, findsNothing);
    await _save(tester);
    expect(repository.added?['fixed_expense_plan_id'], 42);
  });

  testWidgets('the marker is hidden for income', (tester) async {
    await _openForm(tester, FakeFinanceRepository());
    expect(_marker, findsOneWidget);
    await tester.ensureVisible(find.text('Thu nhập'));
    await tester.tap(find.text('Thu nhập'));
    await tester.pumpAndSettle();
    expect(_marker, findsNothing);
  });

  testWidgets('the marker is hidden when there is no plan to attach', (
    tester,
  ) async {
    await _openForm(tester, FakeFinanceRepository(), plans: const []);
    expect(_marker, findsNothing);
  });

  testWidgets('editing keeps a marked expense marked and can clear it', (
    tester,
  ) async {
    final repository = FakeFinanceRepository();
    final marked = Transaction(
      id: 7,
      userId: 'user',
      accountId: 1,
      amount: 2500000,
      transactionType: 'expense',
      transactionDate: DateTime(2026, 11, 3),
      createdAt: DateTime(2026, 11, 3),
      fixedExpensePlanId: 42,
    );
    await _openForm(tester, repository, plans: const [], transaction: marked);
    await tester.ensureVisible(_marker);
    expect(_isOn(tester), isTrue);
    await tester.tap(_marker);
    await tester.pumpAndSettle();
    await _save(tester);
    expect(repository.updated?.containsKey('fixed_expense_plan_id'), isTrue);
    expect(repository.updated?['fixed_expense_plan_id'], isNull);
  });
}
