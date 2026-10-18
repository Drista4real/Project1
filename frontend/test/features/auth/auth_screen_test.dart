import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/auth/screens/auth_screen.dart';
import 'package:project_one/features/auth/cubit/auth_cubit.dart';
import 'package:project_one/features/auth/widgets/auth_gate.dart';
import 'package:project_one/features/settings/cubit/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/device_settings.dart';
import 'auth_cubit_test.dart' show AuthHarness;

void main() {
  late AuthHarness harness;
  setUp(() => harness = AuthHarness());
  tearDown(() => harness.auth.dispose());

  testWidgets(
    'registration validates password confirmation without a request',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(auth: harness.auth, initialMode: AuthMode.register),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('auth-email-field')),
        'alice@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('auth-password-field')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm-field')),
        'different',
      );
      await tester.tap(find.text('Đăng ký').last);
      await tester.pump();
      expect(find.text('Mật khẩu xác nhận chưa khớp'), findsOneWidget);
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets('OTP supports paste, countdown and returning to another email', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(auth: harness.auth, initialMode: AuthMode.otp),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'alice@example.com',
    );
    await tester.tap(find.text('Gửi mã OTP'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-code-field')), findsOneWidget);
    expect(find.textContaining('Gửi lại mã sau'), findsOneWidget);
    expect(jsonDecode(harness.requests.single.body)['create_user'], false);
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Đổi email'),
      120,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi email'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('session gate holds recovery until password is changed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences(
      security: FakeDeviceSecurity(),
      reminders: FakeDailyReminder(),
    );
    await preferences.loadUser(null);
    await tester.pumpWidget(
      AuthGate(
        auth: harness.auth,
        preferences: preferences,
        signedInBuilder: (_) =>
            const MaterialApp(home: Text('private finance')),
      ),
    );
    await tester.ensureVisible(find.text('Quên mật khẩu?'));
    await tester.tap(find.text('Quên mật khẩu?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'alice@example.com',
    );
    await tester.tap(find.text('Gửi mã khôi phục'));
    await tester.pumpAndSettle();
    harness.sessionResponse();
    await tester.enterText(find.byKey(const Key('auth-code-field')), '123456');
    await tester.tap(find.text('Xác minh mã'));
    await tester.pumpAndSettle();
    expect(find.text('private finance'), findsNothing);
    expect(find.text('Đặt mật khẩu mới'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('auth-confirm-field')),
      'new-password',
    );
    await tester.ensureVisible(find.text('Lưu mật khẩu'));
    await tester.tap(find.text('Lưu mật khẩu'));
    await tester.pumpAndSettle();
    expect(find.text('private finance'), findsNothing);
    expect(
      find.text('Đã đổi mật khẩu. Vui lòng đăng nhập lại.'),
      findsOneWidget,
    );
    expect(harness.auth.currentSession, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    preferences.dispose();
  });

  testWidgets('small screen and large text remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: AuthScreen(auth: harness.auth, initialMode: AuthMode.register),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
