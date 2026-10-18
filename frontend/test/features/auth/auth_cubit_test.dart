import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_one/features/auth/cubit/auth_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> authSession({String id = 'alice', bool guest = false}) => {
  'access_token': 'test-access-$id-$guest',
  'refresh_token': 'test-refresh-$id-$guest',
  'token_type': 'bearer',
  'expires_in': 3600,
  'user': {
    'id': id,
    'aud': 'authenticated',
    'email': guest ? null : 'alice@example.com',
    'is_anonymous': guest,
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'created_at': '2026-10-18T00:00:00Z',
  },
};

class AuthHarness {
  AuthHarness() {
    auth = GoTrueClient(
      url: 'https://auth.example.test',
      autoRefreshToken: false,
      flowType: AuthFlowType.implicit,
      httpClient: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }
  late final GoTrueClient auth;
  final requests = <http.Request>[];
  Future<http.Response> Function(http.Request) handler = (_) async =>
      http.Response('{}', 200);
  Map<String, dynamic> get lastBody => jsonDecode(requests.last.body);
  void sessionResponse({String id = 'alice', bool guest = false}) {
    handler = (request) async {
      final session = authSession(id: id, guest: guest);
      return http.Response(
        jsonEncode(request.url.path == '/user' ? session['user'] : session),
        200,
      );
    };
  }
}

void main() {
  late AuthHarness harness;
  late AuthCubit cubit;
  var clock = DateTime(2026, 10, 18);
  setUp(() {
    clock = DateTime(2026, 10, 18);
    harness = AuthHarness();
    cubit = AuthCubit(harness.auth, now: () => clock);
  });
  tearDown(() async {
    await cubit.close();
    harness.auth.dispose();
  });

  test(
    'OTP sends without creating accounts, verifies email and throttles resend',
    () async {
      cubit.setMode(AuthMode.otp);
      await cubit.submit(' alice@example.com ', '');
      expect(harness.lastBody['create_user'], false);
      expect(harness.lastBody['email'], 'alice@example.com');
      expect(cubit.state.step, AuthStep.code);
      await cubit.resend();
      expect(harness.requests, hasLength(1));
      clock = clock.add(const Duration(seconds: 61));
      await cubit.resend();
      expect(harness.requests, hasLength(2));
      harness.sessionResponse();
      await cubit.verify('123456');
      expect(harness.lastBody['type'], 'email');
      expect(cubit.state.authenticated, true);
    },
  );

  test(
    'signup waits for confirmation and resends without retaining password',
    () async {
      cubit.setMode(AuthMode.register);
      await cubit.submit('alice@example.com', ' password ');
      expect(harness.lastBody['password'], ' password ');
      expect(cubit.state.authenticated, false);
      expect(cubit.state.step, AuthStep.code);
      clock = clock.add(const Duration(seconds: 61));
      await cubit.resend();
      expect(harness.requests.last.url.path, '/resend');
      expect(harness.lastBody['type'], 'signup');
      harness.sessionResponse();
      await cubit.verify('123456');
      expect(harness.lastBody['type'], 'email');
      expect(cubit.state.authenticated, true);
    },
  );

  test(
    'password mutation requires verified recovery, then locally signs out',
    () async {
      cubit.setMode(AuthMode.recovery);
      await cubit.savePassword('new-password');
      expect(harness.requests, isEmpty);
      await cubit.submit('alice@example.com', '');
      expect(harness.requests.last.url.path, '/recover');
      harness.sessionResponse();
      await cubit.verify('123456');
      expect(harness.lastBody['type'], 'recovery');
      expect(cubit.state.step, AuthStep.password);
      expect(cubit.state.authenticated, false);
      await cubit.savePassword('new-password');
      expect(
        harness.requests.any(
          (r) =>
              r.method == 'PUT' &&
              jsonDecode(r.body)['password'] == 'new-password',
        ),
        true,
      );
      expect(harness.requests.last.url.queryParameters['scope'], 'local');
      expect(harness.auth.currentSession, isNull);
      expect(cubit.state.mode, AuthMode.login);
    },
  );

  test('invalid OTP retains code step and has a Vietnamese error', () async {
    cubit.setMode(AuthMode.otp);
    await cubit.submit('alice@example.com', '');
    harness.handler = (_) async => http.Response(
      '{"error_code":"otp_expired","msg":"Token expired"}',
      403,
    );
    await cubit.verify('123456');
    expect(cubit.state.step, AuthStep.code);
    expect(cubit.state.message, contains('hết hạn'));
    expect(cubit.state.authenticated, false);
  });

  test(
    'concurrent requests and completed requests after disposal cannot emit',
    () async {
      final response = Completer<http.Response>();
      harness.handler = (_) => response.future;
      cubit.setMode(AuthMode.otp);
      final first = cubit.submit('alice@example.com', '');
      await cubit.submit('alice@example.com', '');
      await cubit.close();
      response.complete(http.Response('{}', 200));
      await first;
      expect(harness.requests, hasLength(1));
    },
  );

  test(
    'old recovery screen cannot change or sign out another account',
    () async {
      cubit.setMode(AuthMode.recovery);
      await cubit.submit('alice@example.com', '');
      harness.sessionResponse();
      await cubit.verify('123456');
      harness.sessionResponse(id: 'bob');
      await harness.auth.signInWithPassword(
        email: 'bob@example.com',
        password: 'password',
      );
      final before = harness.requests.length;
      await cubit.savePassword('new-password');
      await cubit.cancel();
      expect(harness.requests, hasLength(before));
      expect(harness.auth.currentUser?.id, 'bob');
    },
  );
}
