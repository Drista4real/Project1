import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/network/auth_error_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('404 identifies the auth service configuration', () {
    expect(
      authErrorMessage(const AuthException('Not Found', statusCode: '404')),
      contains('URL Supabase'),
    );
  });
  test('unconfirmed email tells the user to verify email', () {
    expect(
      authErrorMessage(
        const AuthException('Unconfirmed', code: 'email_not_confirmed'),
      ),
      contains('email xác nhận'),
    );
  });
  test('rate limit asks user to wait instead of changing credentials', () {
    expect(
      authErrorMessage(const AuthException('Rate limit', statusCode: '429')),
      contains('chờ'),
    );
  });
  test('provider details are not exposed in a server error', () {
    final message = authErrorMessage(
      const AuthException(
        'Database error saving new user: internal details',
        statusCode: '500',
      ),
    );
    expect(message, contains('Máy chủ'));
    expect(message, isNot(contains('internal details')));
  });
  test('email quota does not blame the user for spam', () {
    final message = authErrorMessage(
      const AuthException(
        'Email rate limit exceeded',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      ),
    );
    expect(message, contains('giới hạn gửi email'));
    expect(message, isNot(contains('spam')));
  });
  test('SMTP recipient restriction is distinct from an email quota', () {
    final message = authErrorMessage(
      const AuthException(
        'Email address not authorized',
        code: 'email_address_not_authorized',
      ),
    );
    expect(message, contains('chưa hỗ trợ địa chỉ'));
    expect(message, isNot(contains('giới hạn')));
  });
}
