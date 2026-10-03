import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:project_one/features/dashboard/presentation/screens/settings_screen.dart';

void main() {
  group('DashboardScreen UI', () {
    testWidgets('shows the ledger balance and switches to month list', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sổ thu chi'), findsOneWidget);
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
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tháng này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lịch'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('SettingsScreen UI', () {
    testWidgets('shows search, transaction tags and date ranges', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('# dulich'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Tuần này'), findsOneWidget);
    });

    testWidgets('updates the selected transaction tag', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SettingsScreen()),
      );
      final tag = tester.widget<FilterChip>(find.widgetWithText(FilterChip, '# dulich'));
      expect(tag.selected, isFalse);

      await tester.tap(find.widgetWithText(FilterChip, '# dulich'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, '# dulich')).selected,
        isTrue,
      );
    });
  });
}
