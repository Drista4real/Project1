import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/app_router.dart';
import 'package:project_one/features/chat/screens/chat_home_screen.dart';
import 'package:project_one/features/ledger/screens/ledger_screen.dart';
import 'package:project_one/features/settings/screens/settings_screen.dart';
import 'package:project_one/app/widgets/app_exit_button.dart';

import '../helpers/supabase_test_setup.dart';

void main() {
  configureTestSupabase();

  testWidgets('the home route shows the conversational canvas', (tester) async {
    final router = createAppRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.byType(ChatHomeScreen), findsOneWidget);
    router.dispose();
  });

  testWidgets('the ledger keeps its own route', (tester) async {
    final router = createAppRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go(AppRoutes.ledger);
    await tester.pumpAndSettle();

    expect(find.byType(LedgerScreen), findsOneWidget);
    router.dispose();
  });

  testWidgets('the navigation offers both the canvas and the ledger', (
    tester,
  ) async {
    final router = createAppRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Sổ thu chi'), findsOneWidget);
    router.dispose();
  });

  testWidgets('settings live behind the profile button, not a tab', (
    tester,
  ) async {
    final router = createAppRouter();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    expect(find.text('Cài đặt'), findsNothing);
    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    router.dispose();
  });

  testWidgets('settings back returns to the tab that opened it', (
    tester,
  ) async {
    final router = createAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go(AppRoutes.reports);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(AppExitButton),
      ),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, AppRoutes.settings);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, AppRoutes.reports);
    expect(router.canPop(), isFalse);
  });

  for (final entry in {
    AppRoutes.settings: AppRoutes.home,
    AppRoutes.plan: AppRoutes.home,
    AppRoutes.forecast: AppRoutes.reports,
    AppRoutes.addTransaction: AppRoutes.ledger,
    AppRoutes.aiQuickInput: AppRoutes.home,
  }.entries) {
    for (final systemBack in [false, true]) {
      testWidgets(
        'direct ${entry.key} exits to ${entry.value}, Android Back: $systemBack',
        (tester) async {
          final router = createAppRouter();
          addTearDown(router.dispose);
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          router.go(entry.key);
          await tester.pumpAndSettle();
          expect(router.canPop(), isFalse);
          if (systemBack) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.byType(AppExitButton));
          }
          await tester.pumpAndSettle();
          expect(router.state.matchedLocation, entry.value);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final entry in {
    AppRoutes.plan: ('Ngân sách', AppRoutes.budget),
    AppRoutes.forecast: ('Báo cáo', AppRoutes.reports),
  }.entries) {
    testWidgets('${entry.key} allows returning through its highlighted tab', (
      tester,
    ) async {
      final router = createAppRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go(entry.key);
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.value.$1));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, entry.value.$2);
    });
  }

  for (final route in [
    AppRoutes.home,
    AppRoutes.ledger,
    AppRoutes.reports,
    AppRoutes.budget,
    AppRoutes.plan,
    AppRoutes.forecast,
    AppRoutes.settings,
  ]) {
    testWidgets('$route shows the profile button', (tester) async {
      final router = createAppRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go(route);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(router.state.matchedLocation, route);
      expect(find.byTooltip('Cài đặt'), findsOneWidget);
      router.dispose();
    });
  }
}
