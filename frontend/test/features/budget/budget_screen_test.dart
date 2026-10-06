import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/budget/screens/budget_screen.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import '../../helpers/envelope_fixture.dart';
import '../../helpers/envelope_memory_repository.dart';
import '../../helpers/ui_preview.dart';

final _boundary = GlobalKey();
EnvelopeMemoryRepository budgetFixture() {
  final repo = fixture();
  final now = DateTime.now();
  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
  for (final record in repo.tables['budgets']!) {
    record['month_year'] = monthKey;
  }
  repo.tables['budgets']!.add({
    'id': 50,
    'category_id': null,
    'pillar': null,
    'month_year': monthKey,
    'limit_amount': '20000000',
  });
  repo.tables['transactions']!.addAll([
    {
      'id': 1,
      'category_id': 1,
      'amount': '1200000',
      'transaction_type': 'expense',
      'transaction_date': monthKey,
    },
    {
      'id': 2,
      'category_id': 1,
      'amount': '9000000',
      'transaction_type': 'income',
      'transaction_date': monthKey,
    },
  ]);
  return repo;
}

Future<void> openBudget(
  WidgetTester tester,
  EnvelopeMemoryRepository repo, {
  Size size = const Size(390, 1850),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.kakeiboTheme,
        home: BudgetScreen(insights: FinanceInsights(repo)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (captureUiEnabled) {
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/envelope_zen_header.jpg'),
        _boundary.currentContext!,
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(loadEnvelopeFonts);
  testWidgets(
    'overview shows actual remaining money and four matching envelopes',
    (tester) async {
      await openBudget(tester, budgetFixture());
      expect(find.text('Ngân sách & phong bao'), findsOneWidget);
      expect(find.text('18.800.000 ₫'), findsOneWidget);
      for (final title in [
        'Nhu cầu thiết yếu',
        'Mong muốn & sở thích',
        'Nuôi dưỡng tâm hồn',
        'Dự phòng & bất ngờ',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await captureUi(tester, _boundary, 'budget-overview-full');
    },
  );

  testWidgets(
    'category limit uses shared sheet and saving refreshes overview',
    (tester) async {
      final repo = budgetFixture();
      await openBudget(tester, repo);
      await tester.tap(find.text('2 hạn mức danh mục').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chỉnh hạn mức Ăn uống gia đình'));
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa phong bao'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('envelope-limit')),
        '5000000',
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.tables['budgets']!.first['limit_amount'], '4500000');
      await tester.tap(find.byTooltip('Chỉnh hạn mức Ăn uống gia đình'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('envelope-limit')),
        '5000000',
      );
      await tester.tap(find.text('Lưu hạn mức'));
      await tester.pumpAndSettle();
      expect(repo.tables['budgets']!.first['limit_amount'], '5000000');
      expect(find.text('1.200.000 ₫ / 5.000.000 ₫'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rebalance updates monthly budget and envelope allocation', (
    tester,
  ) async {
    final repo = budgetFixture();
    await openBudget(tester, repo);
    await tester.tap(find.text('Điều chỉnh phân bổ'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rebalance-total')),
      '30000000',
    );
    await tester.tap(find.text('Lưu phân bổ'));
    await tester.pumpAndSettle();
    expect(find.text('28.800.000 ₫'), findsOneWidget);
    expect(
      repo.tables['budgets']!.singleWhere(
        (r) => r['pillar'] == 'needs',
      )['limit_amount'],
      '15000000.00',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('month navigation carries selected month into management', (
    tester,
  ) async {
    await openBudget(tester, budgetFixture());
    await tester.tap(find.byTooltip('Tháng sau'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget-remaining')), findsOneWidget);
    final next = DateTime(DateTime.now().year, DateTime.now().month + 1);
    expect(
      find.text('Ngân sách tháng ${next.month}/${next.year}'),
      findsOneWidget,
    );
    expect(find.text('Định mức mỗi ngày'), findsNothing);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Quản lý danh mục & phong bao'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Phong bao tháng ${next.month}/${next.year}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('overspending keeps negative balance and warning visible', (
    tester,
  ) async {
    final repo = budgetFixture();
    repo.tables['transactions']!.first['amount'] = '25000000';
    await openBudget(tester, repo);
    expect(find.text('−5.000.000 ₫'), findsOneWidget);
    expect(find.text('VƯỢT NGÂN SÁCH'), findsOneWidget);
    expect(find.text('Đã chạm hoặc vượt hạn mức phong bao.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unconfigured month shows actual expenses and can set up budgets',
    (tester) async {
      final repo = budgetFixture();
      repo.tables['budgets']!.clear();
      await openBudget(tester, repo);
      expect(find.text('Chưa thiết lập'), findsOneWidget);
      expect(find.text('Chưa\nphân bổ'), findsNWidgets(4));
      await tester.tap(find.text('Thiết lập ngân sách'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('rebalance-total')),
        '10000000',
      );
      await tester.tap(find.text('Lưu phân bổ'));
      await tester.pumpAndSettle();
      expect(find.text('8.800.000 ₫'), findsOneWidget);
      expect(repo.tables['budgets'], hasLength(5));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets(
      'budget layout fits ${width.toInt()}px and sheet stays usable',
      (tester) async {
        await openBudget(
          tester,
          budgetFixture(),
          size: Size(width, width == 320 ? 640 : 900),
        );
        if (width == 320) {
          await captureUi(tester, _boundary, 'budget-overview-small');
        }
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Điều chỉnh phân bổ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Điều chỉnh phân bổ'));
        await tester.pumpAndSettle();
        if (width == 320) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 260);
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(find.widgetWithText(FilledButton, 'Lưu phân bổ'))
                .bottom,
            lessThanOrEqualTo(380),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
