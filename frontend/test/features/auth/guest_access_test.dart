import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:project_one/features/auth/cubit/auth_cubit.dart';
import 'package:project_one/features/auth/widgets/account_access_card.dart';
import 'package:project_one/features/auth/widgets/auth_gate.dart';
import 'package:project_one/features/settings/cubit/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/device_settings.dart';
import 'auth_cubit_test.dart' show AuthHarness;

void main() {
  late AuthHarness harness;
  setUp(() => harness = AuthHarness());
  tearDown(() => harness.auth.dispose());

  test('guest starts once and links an email on the same UID', () async {
    final cubit = AuthCubit(harness.auth);
    harness.sessionResponse(id: 'guest-1', guest: true);
    await cubit.continueAsGuest();
    expect(harness.auth.currentUser?.isAnonymous, true);
    final requests = harness.requests.length;
    await cubit.continueAsGuest();
    expect(harness.requests, hasLength(requests));
    await cubit.close();
    final link = AuthCubit(harness.auth, initialMode: AuthMode.link);
    await link.submit('alice@example.com', '');
    expect(harness.requests.last.method, 'PUT');
    expect(harness.lastBody['email'], 'alice@example.com');
    harness.sessionResponse(id: 'guest-1');
    await link.verify('123456');
    expect(harness.lastBody['type'], 'email_change');
    expect(harness.auth.currentUser?.id, 'guest-1');
    expect(harness.auth.currentUser?.isAnonymous, false);
    expect(link.state.step, AuthStep.password);
    harness.handler = (_) async => http.Response(
      '{"error_code":"weak_password","msg":"Weak password"}',
      422,
    );
    await link.savePassword('password');
    expect(harness.auth.currentUser?.id, 'guest-1');
    link.finishLink();
    expect(link.state.authenticated, true);
    await link.close();
  });

  test(
    'email conflict keeps guest and code request can be corrected',
    () async {
      harness.sessionResponse(id: 'guest-1', guest: true);
      await harness.auth.signInAnonymously();
      final cubit = AuthCubit(harness.auth, initialMode: AuthMode.link);
      harness.handler = (_) async => http.Response(
        '{"error_code":"email_exists","msg":"Existing email"}',
        422,
      );
      await cubit.submit('existing@example.com', '');
      expect(harness.auth.currentUser?.id, 'guest-1');
      expect(harness.auth.currentUser?.isAnonymous, true);
      expect(cubit.state.step, AuthStep.credentials);
      expect(cubit.state.message, contains('tài khoản khác'));
      await cubit.cancel();
      expect(harness.auth.currentUser?.id, 'guest-1');
      await cubit.close();
    },
  );

  test(
    'auto-confirmed email linking skips a code that will not be sent',
    () async {
      harness.sessionResponse(id: 'guest-1', guest: true);
      await harness.auth.signInAnonymously();
      final cubit = AuthCubit(harness.auth, initialMode: AuthMode.link);
      harness.sessionResponse(id: 'guest-1');
      await cubit.submit('alice@example.com', '');
      expect(cubit.state.step, AuthStep.password);
      expect(harness.auth.currentUser?.id, 'guest-1');
      cubit.finishLink();
      expect(cubit.state.authenticated, true);
      await cubit.close();
    },
  );

  testWidgets(
    'restored guest enters finance without another anonymous signup',
    (tester) async {
      harness.sessionResponse(id: 'guest-1', guest: true);
      await harness.auth.signInAnonymously();
      SharedPreferences.setMockInitialValues({});
      final preferences = AppPreferences(
        security: FakeDeviceSecurity(),
        reminders: FakeDailyReminder(),
      );
      await preferences.loadUser('guest-1');
      await tester.pumpWidget(
        AuthGate(
          auth: harness.auth,
          preferences: preferences,
          signedInBuilder: (_) =>
              const MaterialApp(home: Text('private finance')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('private finance'), findsOneWidget);
      expect(harness.requests, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      preferences.dispose();
    },
  );

  testWidgets(
    'guest exit cancellation keeps its session; confirmation leaves it',
    (tester) async {
      harness.sessionResponse(id: 'guest-1', guest: true);
      await harness.auth.signInAnonymously();
      harness.handler = (_) async => http.Response('{}', 200);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AccountAccessCard(auth: harness.auth)),
        ),
      );
      expect(find.text('Khách'), findsOneWidget);
      await tester.tap(find.byTooltip('Tùy chọn tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.textContaining('không thể khôi phục'), findsWidgets);
      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();
      expect(harness.auth.currentUser?.id, 'guest-1');
      await tester.tap(find.byTooltip('Tùy chọn tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rời chế độ khách'));
      await tester.pumpAndSettle();
      expect(harness.auth.currentSession, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'failed anonymous signup does not manufacture an authenticated state',
    () async {
      harness.handler = (_) async => http.Response(
        jsonEncode({
          'error_code': 'anonymous_provider_disabled',
          'msg': 'Disabled',
        }),
        422,
      );
      final cubit = AuthCubit(harness.auth);
      await cubit.continueAsGuest();
      expect(cubit.state.authenticated, false);
      expect(cubit.state.message, contains('khách chưa được bật'));
      await cubit.close();
    },
  );
}
