import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:project_one/core/config/supabase_config.dart';
import 'finance_api_error.dart';

class FinanceApiException implements Exception {
  final String message;
  const FinanceApiException(this.message);
  @override
  String toString() => message;
}

class BackendClient {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String get baseUrl =>
      (_configuredBaseUrl.isNotEmpty
              ? _configuredBaseUrl
              : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:8000'
              : 'http://localhost:8000')
          .replaceFirst(RegExp(r'/+$'), '');

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    var session = SupabaseConfig.client.auth.currentSession;
    if (session == null) {
      throw const FinanceApiException(
        'Vui lòng đăng nhập để quản lý tài chính.',
      );
    }
    if (session.isExpired) {
      try {
        session = (await SupabaseConfig.client.auth.refreshSession()).session;
      } catch (_) {
        throw const FinanceApiException(
          'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
    }
    if (session == null) {
      throw const FinanceApiException('Vui lòng đăng nhập lại.');
    }
    final client = http.Client();
    final timeout = Duration(seconds: path.startsWith('/ingestion/') ? 30 : 15);
    try {
      final request = http.Request(method, Uri.parse('$baseUrl/api/v1$path'));
      request.headers.addAll({
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await client.send(request).timeout(timeout),
      ).timeout(timeout);
      if (response.statusCode >= 400) {
        Object? detail;
        try {
          final error = jsonDecode(utf8.decode(response.bodyBytes));
          detail = error is Map ? error['detail'] : null;
        } catch (_) {
          // A proxy may return a non-JSON error page.
        }
        throw FinanceApiException(
          financeApiErrorMessage(response.statusCode, path, detail),
        );
      }
      return response.statusCode == 204
          ? null
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FinanceApiException {
      rethrow;
    } catch (_) {
      throw const FinanceApiException(
        'Không thể kết nối máy chủ. Vui lòng thử lại.',
      );
    } finally {
      client.close();
    }
  }
}
