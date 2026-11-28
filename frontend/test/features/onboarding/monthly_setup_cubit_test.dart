import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/onboarding/cubit/monthly_setup_cubit.dart';

import 'fake_setup_repository.dart';

final _today = DateTime(2026, 11, 12, 9, 30);

void main() {
  group('MonthlySetupCubit', () {
    test('prefills the answers from what the server knows', () async {
      final cubit = MonthlySetupCubit(FakeSetupRepository(), today: _today);
      addTearDown(cubit.close);

      await cubit.start();
      final state = cubit.state;

      expect(state.loadingDefaults, isFalse);
      expect(state.amount, 8000000);
      expect(state.prefilledBalance, 8000000);
      expect(state.hasFixedIncome, isTrue);
      expect(state.incomeSource, 'payroll_day');
      expect(state.durationDays, 23);
      expect(state.fixedTotal, 3100000);
      expect(state.savingsTarget, 800000);
      // Recurring expenses come first; presets they already cover are dropped.
      expect(state.fixedExpenses.first.label, 'Tiền nhà');
      expect(
        state.fixedExpenses.where((item) => item.label == 'Tiền nhà'),
        hasLength(1),
      );
      expect(
        state.fixedExpenses.map((item) => item.label),
        contains('Học phí'),
      );
    });

    test('a paid or unticked expense does not count', () async {
      final cubit = MonthlySetupCubit(FakeSetupRepository(), today: _today);
      addTearDown(cubit.close);
      await cubit.start();

      cubit.setFixedPaid(0, true);
      expect(cubit.state.fixedTotal, 600000);

      cubit.toggleFixed(1, false);
      expect(cubit.state.fixedTotal, 0);

      cubit.addFixed('Gửi xe');
      final added = cubit.state.fixedExpenses.length - 1;
      cubit.setFixedAmount(added, 150000);
      expect(cubit.state.fixedTotal, 150000);
    });

    test('a flexible income plans thirty days', () async {
      final cubit = MonthlySetupCubit(FakeSetupRepository(), today: _today);
      addTearDown(cubit.close);
      await cubit.start();

      cubit.setHasFixedIncome(false);

      expect(cubit.state.durationDays, 30);
    });

    test('a chosen income date sets the length of the plan', () async {
      final cubit = MonthlySetupCubit(FakeSetupRepository(), today: _today);
      addTearDown(cubit.close);
      await cubit.start();

      cubit.setIncomeDate(DateTime(2026, 11, 25));

      expect(cubit.state.durationDays, 13);
      expect(cubit.state.incomeSource, 'manual');
    });

    test('missing defaults leave the user to type the answers', () async {
      final cubit = MonthlySetupCubit(
        FakeSetupRepository(failDefaults: true),
        today: _today,
      );
      addTearDown(cubit.close);

      await cubit.start();

      expect(cubit.state.defaultsError, isNotNull);
      expect(cubit.state.amount, 0);
      expect(cubit.state.canContinue, isFalse);
      expect(cubit.state.fixedExpenses, hasLength(presetFixedExpenses.length));
      expect(cubit.state.durationDays, 30);
    });

    test('the preview sends the answers to the engine', () async {
      final repository = FakeSetupRepository();
      final cubit = MonthlySetupCubit(repository, today: _today);
      addTearDown(cubit.close);
      await cubit.start();
      cubit.setStyle(SpendingStyle.saving);

      await cubit.goTo(5);

      final draft = repository.previews.last;
      expect(draft.totalIncome, 8000000);
      expect(draft.durationDays, 23);
      expect(draft.fixedExpenses, 3100000);
      expect(draft.savingsTarget, 800000);
      expect(
        [draft.foodRatio, draft.transportRatio, draft.lifestyleRatio],
        [70, 15, 15],
      );
      expect(draft.toJson()['start_date'], '2026-11-12');
      expect(draft.toJson()['total_income'], '8000000.00');
      expect(cubit.state.preview?.spendableBudget, 4100000);
      expect(cubit.state.canContinue, isTrue);
    });

    test('a refused preview keeps the user on the last step', () async {
      final cubit = MonthlySetupCubit(
        FakeSetupRepository(
          previewError: 'Số tiền chi tiêu được phải lớn hơn 0',
        ),
        today: _today,
      );
      addTearDown(cubit.close);
      await cubit.start();

      await cubit.goTo(5);

      expect(cubit.state.preview, isNull);
      expect(cubit.state.previewError, 'Số tiền chi tiêu được phải lớn hơn 0');
      expect(cubit.state.canContinue, isFalse);
    });

    test('a typed saving waits for the screen to ask the engine', () async {
      final repository = FakeSetupRepository();
      final cubit = MonthlySetupCubit(repository, today: _today);
      addTearDown(cubit.close);
      await cubit.start();

      cubit.setCustomSavings(500000);

      expect(cubit.state.savingsPercent, isNull);
      expect(cubit.state.savingsTarget, 500000);
      expect(repository.previews, isEmpty);
    });

    test('starting the plan saves it once with one idempotency key', () async {
      final repository = FakeSetupRepository();
      final cubit = MonthlySetupCubit(repository, today: _today);
      addTearDown(cubit.close);
      await cubit.start();
      await cubit.goTo(5);

      await cubit.next();
      await cubit.submit();

      expect(cubit.state.created?.id, 7);
      expect(repository.created, hasLength(1));
      expect(
        repository.created.single.idempotencyKey,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });

  group('balance sync', () {
    test(
      'a started plan sets the ledger balance to the stated amount',
      () async {
        final synced = <num>[];
        final cubit = MonthlySetupCubit(
          FakeSetupRepository(),
          today: _today,
          syncBalance: (amount) async => synced.add(amount),
        );
        addTearDown(cubit.close);
        await cubit.start();
        cubit.setAmount(5000000);
        await cubit.goTo(5);

        await cubit.submit();

        expect(cubit.state.created, isNotNull);
        expect(synced, [5000000]);
        expect(cubit.state.balanceSyncError, isNull);
      },
    );

    test('a failed sync keeps the plan and warns the user', () async {
      final cubit = MonthlySetupCubit(
        FakeSetupRepository(),
        today: _today,
        syncBalance: (_) async => throw Exception('offline'),
      );
      addTearDown(cubit.close);
      await cubit.start();
      await cubit.goTo(5);

      await cubit.submit();

      expect(cubit.state.created, isNotNull);
      expect(cubit.state.balanceSyncError, isNotNull);
    });

    test('nothing is synced when the plan is not saved', () async {
      final synced = <num>[];
      final cubit = MonthlySetupCubit(
        FakeSetupRepository(previewError: 'Không đủ tiền'),
        today: _today,
        syncBalance: (amount) async => synced.add(amount),
      );
      addTearDown(cubit.close);
      await cubit.start();
      await cubit.goTo(5);

      await cubit.submit();

      expect(cubit.state.created, isNull);
      expect(synced, isEmpty);
    });
  });
}
