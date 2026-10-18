import 'memory_management_repository.dart';

/// Disposable records and representative management fields for UI verification.
class ManagementFixture extends MemoryManagementRepository {
  ManagementFixture() {
    catalog.clear();
    Map<String, dynamic> text([Object? value]) => {
      'type': 'string',
      'default': ?value,
    };
    Map<String, dynamic> money([Object value = 0]) => {
      'type': 'number',
      'minimum': 0,
      'default': value,
    };
    Map<String, dynamic> optional(String type) => {
      'anyOf': [
        {'type': type},
        {'type': 'null'},
      ],
      'default': null,
    };
    void module(
      String name,
      String title,
      Map<String, dynamic> properties, [
      List<String> required = const [],
    ]) {
      catalog.add({
        'name': name,
        'title': title,
        'schema': {'properties': properties, 'required': required},
      });
    }

    module(
      'accounts',
      'Ví và tài khoản',
      {
        'name': text(),
        'account_type': {
          'type': 'string',
          'enum': [
            'cash',
            'bank',
            'e_wallet',
            'credit_card',
            'investment',
            'savings',
          ],
        },
        'balance': {'type': 'number', 'default': 0},
        'currency': {
          'type': 'string',
          'pattern': r'^[A-Z]{3}$',
          'default': 'VND',
        },
        'icon': text('account_balance_wallet'),
        'color': {
          'type': 'string',
          'pattern': r'^#[0-9a-fA-F]{6}$',
          'default': '#10B981',
        },
        'account_number': optional('string'),
        'institution_name': optional('string'),
        'credit_limit': money(),
        'statement_day': optional('integer'),
        'payment_due_day': optional('integer'),
        'is_included_in_total': {'type': 'boolean', 'default': true},
        'is_archived': {'type': 'boolean', 'default': false},
      },
      ['name', 'account_type'],
    );
    module(
      'recurring_transactions',
      'Giao dịch định kỳ',
      {
        'description': text(),
        'amount': money(),
        'transaction_type': {
          'type': 'string',
          'enum': ['income', 'expense'],
        },
        'frequency': {
          'type': 'string',
          'enum': ['monthly', 'weekly', 'yearly'],
        },
        'start_date': {'type': 'string', 'format': 'date'},
        'next_execution_date': {'type': 'string', 'format': 'date'},
      },
      [
        'description',
        'amount',
        'transaction_type',
        'frequency',
        'start_date',
        'next_execution_date',
      ],
    );
    module('debts_loans', 'Sổ nợ và cho vay', {
      'person_name': text(),
      'amount': money(),
      'paid_amount': money(),
      'due_date': optional('string'),
    });
    module('saving_goals', 'Mục tiêu tiết kiệm', {
      'name': text(),
      'target_amount': money(),
      'current_amount': money(),
      'target_date': optional('string'),
    });
    module('tags', 'Thẻ', {'name': text(), 'color': text('#64748B')}, ['name']);
    module('cashflow_forecasts', 'Dự báo dòng tiền', {
      'forecast_date': text(),
      'predicted_balance': money(),
    });
    module('ai_consultations', 'Lịch sử tư vấn', {
      'user_query': text(),
      'ai_recommendation': text(),
    });
  }

  final tables = <String, List<Map<String, dynamic>>>{
    'accounts': [
      {
        'id': 1,
        'name': 'Tiền mặt',
        'account_type': 'cash',
        'balance': '650000',
        'currency': 'VND',
        'icon': 'payments',
        'color': '#10B981',
        'credit_limit': '0',
        'is_included_in_total': true,
        'is_archived': false,
      },
      {
        'id': 2,
        'name': 'Tài khoản sinh hoạt',
        'account_type': 'bank',
        'balance': '12500000',
        'currency': 'VND',
        'institution_name': 'Ngân hàng',
        'icon': 'account_balance',
        'color': '#2D5A43',
        'credit_limit': '0',
        'is_included_in_total': true,
        'is_archived': false,
      },
    ],
    'recurring_transactions': [
      {
        'id': 3,
        'description': 'Tiền nhà hằng tháng',
        'amount': '4000000',
        'transaction_type': 'expense',
        'frequency': 'monthly',
        'start_date': '2026-10-01',
        'next_execution_date': '2026-11-01',
      },
    ],
    'debts_loans': [
      {
        'id': 4,
        'person_name': 'Nguyễn Minh Anh',
        'amount': '2000000',
        'paid_amount': '500000',
        'due_date': '2026-11-15',
      },
    ],
    'saving_goals': [
      {
        'id': 5,
        'name': 'Quỹ dự phòng',
        'target_amount': '30000000',
        'current_amount': '7500000',
      },
    ],
    'tags': [
      {'id': 6, 'name': 'Du lịch hè', 'color': '#D96B43'},
    ],
    'cashflow_forecasts': [],
    'ai_consultations': [],
  };

  @override
  Future<Map<String, dynamic>> page(String resource, {int offset = 0}) async {
    final rows = tables[resource] ?? [];
    return {'items': rows.skip(offset).take(30).toList(), 'total': rows.length};
  }

  @override
  Future<Map<String, dynamic>> get(String resource, String key) async =>
      Map.from(tables[resource]!.firstWhere((row) => '${row['id']}' == key));
  @override
  Future<List<Map<String, dynamic>>> references(String resource) async =>
      tables[resource] ?? [];
  @override
  Future<void> save(
    String resource,
    Map<String, dynamic> values, {
    String? key,
  }) async {
    saved = Map.from(values);
    savedKey = key;
    if (key == null) {
      (tables[resource] ??= []).add({'id': 100, ...values});
    } else {
      tables[resource]!
          .firstWhere((row) => '${row['id']}' == key)
          .addAll(values);
    }
  }
}
