import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/transactions/cubit/transaction_form_cubit.dart';
import '../../helpers/fake_finance_repository.dart';

class PendingSaveRepository extends FakeFinanceRepository {
  final saveRequest = Completer<void>();
  var saves = 0;
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
    saves++;
    await saveRequest.future;
  }
}

void main() {
  test('double submission sends only one transaction request', () async {
    final repository = PendingSaveRepository();
    final cubit = TransactionFormCubit(repository);
    addTearDown(cubit.close);
    await cubit.loadReferences();
    final first = cubit.save(45000, 'Cà phê');
    await cubit.save(45000, 'Cà phê');
    expect(repository.saves, 1);
    repository.saveRequest.complete();
    await first;
    expect(cubit.state.saved, isTrue);
    expect(cubit.state.saving, isFalse);
  });

  test('a failed save enables retry and reports the error', () async {
    final repository = PendingSaveRepository();
    final cubit = TransactionFormCubit(repository);
    addTearDown(cubit.close);
    await cubit.loadReferences();
    final save = cubit.save(45000, 'Cà phê');
    repository.saveRequest.completeError(StateError('offline'));
    await save;
    expect(cubit.state.saving, isFalse);
    expect(cubit.state.saved, isFalse);
    expect(cubit.state.saveError, contains('offline'));
  });

  test(
    'changing type clears category and reload preserves a cleared choice',
    () async {
      final repository = FakeFinanceRepository();
      final cubit = TransactionFormCubit(
        repository,
        transaction: repository.transaction,
      );
      addTearDown(cubit.close);
      await cubit.loadReferences();
      expect(cubit.state.selected?.id, 1);
      cubit.selectType('income');
      expect(cubit.state.selected, isNull);
      await cubit.loadReferences();
      expect(cubit.state.type, 'income');
      expect(cubit.state.selected, isNull);
    },
  );

  test(
    'edit preserves wallet, exact money, category and UTC date in payload',
    () async {
      final repository = FakeFinanceRepository();
      final cubit = TransactionFormCubit(
        repository,
        transaction: repository.transaction,
      );
      addTearDown(cubit.close);
      await cubit.loadReferences();
      await cubit.save(45000.25, ' Cà phê ');
      expect(repository.updated!['amount'], '45000.25');
      expect(repository.updated!['account_id'], 1);
      expect(repository.updated!['category_id'], 1);
      expect(
        repository.updated!['transaction_date'],
        repository.transaction.transactionDate.toUtc().toIso8601String(),
      );
      expect(repository.updated!['raw_description'], 'Cà phê');
    },
  );
}
