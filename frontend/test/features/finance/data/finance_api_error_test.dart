import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/network/finance_api_error.dart';

void main() {
  test('missing operation explains stale backend instead of deleted data', () {
    expect(
      financeApiErrorMessage(
        404,
        '/manage/accounts/42/initial-income',
        'Not Found',
      ),
      contains('khởi động lại API'),
    );
    expect(
      financeApiErrorMessage(404, '/manage/accounts/42', 'Record not found'),
      contains('Dữ liệu không còn tồn tại'),
    );
  });
  test('missing migration and domain rejection retain actionable detail', () {
    expect(
      financeApiErrorMessage(
        503,
        '/manage/accounts',
        'Cần áp dụng migration mới.',
      ),
      'Cần áp dụng migration mới.',
    );
    expect(
      financeApiErrorMessage(
        422,
        '/manage/accounts/42/initial-income',
        'Ví đã có giao dịch.',
      ),
      'Ví đã có giao dịch.',
    );
    expect(
      financeApiErrorMessage(422, '/manage/accounts', ['invalid']),
      contains('biểu mẫu'),
    );
  });
}
