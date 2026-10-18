import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/management/screens/management_screen.dart';
import '../../helpers/management_fixture.dart';

void main() {
  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('management hub, details and form fit $width, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = ManagementFixture();
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.kakeiboDarkTheme : AppTheme.kakeiboTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.5 : 1)),
              child: child!,
            ),
            home: ManagementScreen(repository: repository),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Ví và tài khoản'));
        await tester.tap(find.text('Ví và tài khoản'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tài khoản sinh hoạt'));
        await tester.pumpAndSettle();
        expect(find.text('12.500.000 ₫'), findsWidgets);
        await tester.tap(find.widgetWithText(FilledButton, 'Chỉnh sửa'));
        await tester.pumpAndSettle();
        expect(find.text('Lưu thay đổi'), findsOneWidget);
        expect(find.byKey(const ValueKey('account_number')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
