import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:project_one/features/dashboard/presentation/screens/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'transaction_crud_test.dart' show FakeFinanceRepository;

class MemoryAuthStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_example',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: MemoryAuthStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  group('DashboardScreen UI', () {
    testWidgets('negative wallet balance keeps its sign', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
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
          home: DashboardScreen(
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
        MaterialApp(home: DashboardScreen(repository: FakeFinanceRepository())),
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

  group('SettingsScreen UI', () {
    testWidgets('shows search, transaction tags and date ranges', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('# dulich'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      expect(find.text('Tuần này'), findsOneWidget);
    });

    testWidgets('updates the selected transaction tag', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      final tag = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, '# dulich'),
      );
      expect(tag.selected, isFalse);

      await tester.tap(find.widgetWithText(FilterChip, '# dulich'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, '# dulich'))
            .selected,
        isTrue,
      );
    });
  });
}
