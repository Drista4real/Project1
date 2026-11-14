import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/app_router.dart';
import 'package:project_one/features/chat/screens/chat_home_screen.dart';
import 'package:project_one/features/ledger/screens/ledger_screen.dart';
import 'package:project_one/features/settings/screens/settings_screen.dart';

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
