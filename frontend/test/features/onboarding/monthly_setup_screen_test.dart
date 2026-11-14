import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/features/onboarding/screens/monthly_setup_screen.dart';
import 'package:project_one/features/plan/models/budget_plan_models.dart';

import 'fake_setup_repository.dart';

final _today = DateTime(2026, 11, 12);
final syncedBalances = <num>[];

class PendingDefaultsRepository extends FakeSetupRepository {
  final pending = Completer<SetupDefaults>();
  @override
  Future<SetupDefaults> setupDefaults() => pending.future;
}

class PendingCreateRepository extends FakeSetupRepository {
  final pending = Completer<void>();
  @override
  Future<BudgetPlan> create(PlanDraft draft) async {
    await pending.future;
    return super.create(draft);
  }
}

Future<void> _pumpSetup(
  WidgetTester tester,
  FakeSetupRepository repository, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoutes.monthlySetup,
    routes: [
      GoRoute(path: AppRoutes.home, builder: (_, _) => const Text('HOME')),
      GoRoute(path: AppRoutes.plan, builder: (_, _) => const Text('PLAN')),
      GoRoute(
        path: AppRoutes.monthlySetup,
        builder: (_, _) => MonthlySetupScreen(
          repository: repository,
          today: _today,
          syncBalance: (amount) async => syncedBalances.add(amount),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('setup-next')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Android Back reverses a step, then exits direct setup to home', (
    tester,
  ) async {
    final repository = FakeSetupRepository();
    await _pumpSetup(tester, repository);
    expect(find.byTooltip('Đóng'), findsOneWidget);
    await _next(tester);
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('BƯỚC 1/6'), findsOneWidget);
    expect(find.text('8.000.000'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets(
    'setup can close while defaults are loading and ignores a late response',
    (tester) async {
      final repository = PendingDefaultsRepository();
      await _pumpSetup(tester, repository, settle: false);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      repository.pending.complete(await FakeSetupRepository().setupDefaults());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(repository.created, isEmpty);
    },
  );

  testWidgets('setup cannot exit or go backwards while submitting', (
    tester,
  ) async {
    final repository = PendingCreateRepository();
    await _pumpSetup(tester, repository);
    for (var step = 0; step < 5; step++) {
      await _next(tester);
    }
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Bỏ qua'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Quay lại'),
          )
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('BƯỚC 6/6'), findsOneWidget);
    repository.pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('PLAN'), findsOneWidget);
    expect(repository.created, hasLength(1));
  });
  testWidgets('the six steps lead to a saved plan', (tester) async {
    final repository = FakeSetupRepository();
    await _pumpSetup(tester, repository);

    expect(find.text('BƯỚC 1/6'), findsOneWidget);
    expect(find.text('Bạn đang có bao nhiêu tiền?'), findsOneWidget);
    expect(find.text('8.000.000'), findsOneWidget);

    await _next(tester);
    expect(find.text('Kế hoạch dài 23 ngày'), findsOneWidget);
    expect(find.text('Theo ngày nhận lương trong hồ sơ'), findsOneWidget);

    await _next(tester);
    expect(find.text('Khoản chi cố định trước 05/12'), findsOneWidget);
    expect(find.text('3.100.000 ₫'), findsOneWidget);

    await _next(tester);
    expect(find.text('Muốn để dành bao nhiêu?'), findsOneWidget);
    expect(find.text('800.000 ₫'), findsWidgets);
    // The running total is the engine's spendable budget.
    expect(find.text('4.100.000 ₫'), findsOneWidget);

    await _next(tester);
    expect(find.text('Cân bằng'), findsOneWidget);
    final bar = tester.getSize(
      find.byKey(const ValueKey('ratio-bar-balanced')),
    );
    expect(bar.height, 8);
    expect(bar.width, greaterThan(300));

    await _next(tester);
    expect(find.text('Kế hoạch của bạn'), findsOneWidget);
    expect(find.text('178.261 ₫'), findsOneWidget);
    expect(find.text('Bắt đầu kế hoạch'), findsOneWidget);

    syncedBalances.clear();
    await _next(tester);
    expect(repository.created, hasLength(1));
    expect(syncedBalances, [8000000]);
    expect(find.text('PLAN'), findsOneWidget);
  });

  testWidgets('the start is locked while the money does not cover the plan', (
    tester,
  ) async {
    final repository = FakeSetupRepository(
      previewError: 'Số tiền chi tiêu được phải lớn hơn 0',
    );
    await _pumpSetup(tester, repository);
    for (var step = 0; step < 5; step++) {
      await _next(tester);
    }

    expect(find.text('Chưa lập được kế hoạch'), findsOneWidget);
    expect(find.text('Số tiền chi tiêu được phải lớn hơn 0'), findsOneWidget);
    final start = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('setup-next')),
    );
    expect(start.onPressed, isNull);

    await tester.tap(find.text('Sửa số tiền hiện có'));
    await tester.pumpAndSettle();
    expect(find.text('BƯỚC 1/6'), findsOneWidget);
  });

  testWidgets('a fixed expense added from the dialog joins the list', (
    tester,
  ) async {
    await _pumpSetup(tester, FakeSetupRepository());
    await _next(tester);
    await _next(tester);
    expect(find.text('BƯỚC 3/6'), findsOneWidget);

    await tester.ensureVisible(find.text('Thêm khoản khác'));
    await tester.tap(find.text('Thêm khoản khác'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Gửi xe');
    await tester.tap(find.widgetWithText(FilledButton, 'Thêm'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gửi xe'), findsOneWidget);
  });

  testWidgets('skipping leaves the setup without saving anything', (
    tester,
  ) async {
    final repository = FakeSetupRepository();
    await _pumpSetup(tester, repository);

    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(repository.created, isEmpty);
  });

  testWidgets('without defaults the amount must be typed first', (
    tester,
  ) async {
    await _pumpSetup(tester, FakeSetupRepository(failDefaults: true));

    expect(find.textContaining('Chưa lấy được số dư'), findsOneWidget);
    await _next(tester);
    expect(find.text('BƯỚC 1/6'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('setup-amount')),
      '5000000',
    );
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('setup-amount')),
    );
    expect(field.controller!.text, '5.000.000');
    await _next(tester);
    expect(find.text('BƯỚC 2/6'), findsOneWidget);
    expect(find.text('Kế hoạch dài 30 ngày'), findsOneWidget);
  });
}
