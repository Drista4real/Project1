import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/ledger/screens/ledger_screen.dart';
import '../../helpers/fake_finance_repository.dart';
import '../../helpers/memory_management_repository.dart';
import '../../helpers/supabase_test_setup.dart';

void main() {
  configureTestSupabase();
  group('LedgerScreen UI', () {
    testWidgets('ledger opens category management on a narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: LedgerScreen(
            repository: FakeFinanceRepository(),
            managementRepository: MemoryManagementRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Danh mục'));
      await tester.tap(find.text('Danh mục'));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý danh mục & phong bao'), findsOneWidget);
      expect(find.text('Nhu cầu thiết yếu'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Thêm danh mục mới'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets('negative wallet balance keeps its sign', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LedgerScreen(
            repository: FakeFinanceRepository(balance: -45000),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final balance = tester.widget<Text>(
        find.byKey(const ValueKey('availableBalance')),
      );
      expect(balance.data, '-45.000₫');
    });
    testWidgets('shows the ledger balance and switches to month list', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LedgerScreen(
            repository: FakeFinanceRepository(balance: 18450000),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sổ thu chi'), findsWidgets);
      expect(find.text('CÒN DƯ KHẢ DỤNG'), findsOneWidget);
      expect(find.textContaining('18.450.000₫'), findsOneWidget);
      expect(find.text('Lịch'), findsOneWidget);
      expect(find.text('Tháng này'), findsOneWidget);

      await tester.tap(find.text('Tháng này'));
      await tester.pumpAndSettle();

      expect(find.text('Lịch'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
    });

    testWidgets('shows the calendar after selecting calendar mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: LedgerScreen(repository: FakeFinanceRepository())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tháng này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(
        find.widgetWithIcon(IconButton, Icons.chevron_right),
        findsOneWidget,
      );
    });
  });
}
