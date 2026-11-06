import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/app/app_routes.dart';
import 'package:project_one/app/app_router.dart';
import 'package:project_one/features/chat/screens/chat_home_screen.dart';
import 'package:project_one/features/ledger/screens/ledger_screen.dart';

void main() {
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
}
