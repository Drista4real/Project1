import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/app/kakeibo_app.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_one/app/app_dependencies.dart';

void main() {
  testWidgets('theme preference changes the actual application theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KakeiboZenApp());
    await AppDependencies.preferences.setDarkMode(true);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await AppDependencies.preferences.setDarkMode(false);
  });
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KakeiboZenApp());
    expect(find.byType(KakeiboZenApp), findsOneWidget);
  });
}
