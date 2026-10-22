import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/management/cubit/record_form_cubit.dart';
import 'package:project_one/features/management/screens/record_form_screen.dart';
import 'package:project_one/features/management/screens/resource_list_screen.dart';
import '../../helpers/management_fixture.dart';
import '../../helpers/memory_management_repository.dart';

class RetryRepository extends MemoryManagementRepository {
  final attempts = <Map<String, dynamic>>[];
  @override
  Future<void> save(
    String resource,
    Map<String, dynamic> values, {
    String? key,
  }) async {
    attempts.add(Map.of(values));
    if (attempts.length == 1) throw Exception('Mất kết nối');
    await super.save(resource, values, key: key);
  }
}

class IncomeFixture extends ManagementFixture {
  String? calledPath;
  Map<String, dynamic>? incomeRequest;
  @override
  Future<Map<String, dynamic>> create(
    String resource,
    Map<String, dynamic> values,
  ) async {
    calledPath = resource;
    incomeRequest = Map.of(values);
    final wallet = tables['accounts']!.first;
    wallet['initial_income_request_id'] = values['client_request_id'];
    return Map.of(wallet);
  }
}

void main() {
  testWidgets(
    'existing opening balance requires confirmation and hides action after recording',
    (tester) async {
      final repo = IncomeFixture();
      final wallet = repo.tables['accounts']!.first;
      wallet['balance'] = '10000000';
      final resource = repo.catalog.firstWhere((r) => r['name'] == 'accounts');
      await tester.pumpWidget(
        MaterialApp(
          home: ResourceListScreen(resource: resource, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(wallet['name'] as String));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghi nhận số dư ban đầu là thu nhập'));
      await tester.pumpAndSettle();
      expect(repo.calledPath, isNull);
      await tester.tap(find.text('Ghi nhận thu nhập'));
      await tester.pumpAndSettle();
      expect(repo.calledPath, 'accounts/${wallet['id']}/initial-income');
      expect(repo.incomeRequest!['expected_balance'], '10000000');
      expect(
        repo.incomeRequest!['client_request_id'],
        matches(RegExp(r'^[a-f0-9]{32}$')),
      );
      expect(wallet['balance'], '10000000');
      await tester.tap(find.text(wallet['name'] as String));
      await tester.pumpAndSettle();
      expect(find.text('Ghi nhận số dư ban đầu là thu nhập'), findsNothing);
    },
  );
  test('income retries reuse one request key', () async {
    final repo = RetryRepository();
    final cubit = RecordFormCubit(repo, 'accounts', {});
    addTearDown(cubit.close);
    await cubit.loadReferences();
    const data = {'record_initial_income': true, 'balance': '10000000'};
    await cubit.save(data);
    expect(cubit.state.saved, isFalse);
    await cubit.save(data);
    expect(cubit.state.saved, isTrue);
    expect(
      repo.attempts.first['client_request_id'],
      matches(RegExp(r'^[a-f0-9]{32}$')),
    );
    expect(
      repo.attempts.last['client_request_id'],
      repo.attempts.first['client_request_id'],
    );
  });

  testWidgets(
    'new wallet exposes income choice without internal request field',
    (tester) async {
      final repo = ManagementFixture();
      final resource = repo.catalog.firstWhere((r) => r['name'] == 'accounts');
      await tester.pumpWidget(
        MaterialApp(
          home: RecordFormScreen(
            resource: resource,
            repository: repo,
            initialValues: const {'account_type': 'e_wallet'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('record_initial_income')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('client_request_id')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('name')), 'Ví điện tử');
      await tester.enterText(find.byKey(const ValueKey('balance')), '0');
      await tester.ensureVisible(
        find.byKey(const ValueKey('record_initial_income')),
      );
      await tester.tap(find.byKey(const ValueKey('record_initial_income')));
      await tester.tap(find.text('Thêm ví'));
      await tester.pumpAndSettle();
      expect(find.text('Thu nhập phải lớn hơn 0.'), findsOneWidget);
      expect(repo.saved, isNull);
    },
  );
}
