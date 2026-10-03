import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/core/network/backend_client.dart';
import 'package:project_one/features/finance/data/datasources/finance_remote_data_source.dart';

class StubApi extends BackendClient {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add({'method': method, 'path': path, 'body': body});
    if (method != 'GET') return null;
    if (path == '/accounts') {
      return [
        {'id': 1, 'name': 'Cash'},
      ];
    }
    final row = {
      'id': 1,
      'user_id': 'user',
      'amount': '45000.25',
      'transaction_type': 'expense',
      'account_id': 1,
      'category_id': 2,
      'categories': {'name': 'Food'},
      'transaction_date': '2026-10-03T00:00:00Z',
      'created_at': '2026-10-03T00:00:00Z',
    };
    if (path.contains('offset=0')) {
      return {
        'items': [row],
        'total': 2,
      };
    }
    return {
      'items': [
        {...row, 'id': 2},
      ],
      'total': 2,
    };
  }
}

void main() {
  test('list consumes paginated API and parses exact money strings', () async {
    final api = StubApi();
    final source = FinanceRemoteDataSource(api: api);
    final rows = await source.getTransactions();
    expect(rows.map((row) => row.id), [1, 2]);
    expect(rows.first.amount, 45000.25);
    expect(rows.first.categoryName, 'Food');
    expect(api.calls.last['path'], '/transactions?limit=100&offset=1');
  });

  test('create sends Decimal string, wallet and UTC date to backend', () async {
    final api = StubApi();
    final source = FinanceRemoteDataSource(api: api);
    await source.addTransaction(
      amount: 45000.25,
      transactionType: 'expense',
      description: 'Cà phê',
      accountId: 1,
      categoryId: 2,
      transactionDate: DateTime.utc(2026, 10, 3),
    );
    expect(api.calls.single['method'], 'POST');
    expect(api.calls.single['path'], '/transactions');
    final body = api.calls.single['body'] as Map<String, dynamic>;
    expect(body['amount'], '45000.25');
    expect(body['account_id'], 1);
    expect(body['transaction_date'], endsWith('Z'));
    expect(body.containsKey('user_id'), isFalse);
  });

  test('patch forwards explicit null; delete uses backend endpoint', () async {
    final api = StubApi();
    final source = FinanceRemoteDataSource(api: api);
    await source.updateTransaction(7, {'category_id': null});
    await source.deleteTransaction(7);
    expect(api.calls.first, {
      'method': 'PATCH',
      'path': '/transactions/7',
      'body': {'category_id': null},
    });
    expect(api.calls.last['method'], 'DELETE');
    expect(api.calls.last['path'], '/transactions/7');
  });
}
