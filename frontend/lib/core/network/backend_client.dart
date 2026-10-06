import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:project_one/core/config/supabase_config.dart';

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
    try {
      final request = http.Request(method, Uri.parse('$baseUrl/api/v1$path'));
      request.headers.addAll({
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode >= 400) {
        final message = switch (response.statusCode) {
          401 => 'Phiên đã hết hạn. Vui lòng đăng nhập lại.',
          403 => 'Bạn không có quyền thực hiện thao tác này.',
          404 => 'Dữ liệu không còn tồn tại. Vui lòng tải lại.',
          409 =>
            'Dữ liệu đang được sử dụng, bị trùng hoặc đã thay đổi. Vui lòng kiểm tra lại.',
          422 => 'Kiểm tra giá trị và dữ liệu liên quan trong biểu mẫu.',
          503 => 'Máy chủ chưa sẵn sàng. Vui lòng thử lại sau.',
          _ => 'Không thể xử lý yêu cầu. Vui lòng thử lại.',
        };
        if (path.startsWith('/manage/') &&
            {403, 409, 422}.contains(response.statusCode)) {
          try {
            final error = jsonDecode(utf8.decode(response.bodyBytes));
            final detail = error is Map ? error['detail'] : null;
            if (detail is String && detail.length <= 2000) {
              throw FinanceApiException(detail);
            }
          } on FinanceApiException {
            rethrow;
          } catch (_) {
            // Retain a readable fallback if a proxy returns a non-JSON error.
          }
        }
        throw FinanceApiException(message);
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
