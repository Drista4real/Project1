import 'package:project_one/features/finance/domain/repositories/management_repository.dart';

class MemoryManagementRepository implements ManagementRepository {
  Map<String, dynamic>? saved;
  String? savedKey;
  bool deleted = false;
  final records = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Du lịch', 'color': '#64748B'},
  ];
  final catalog = <Map<String, dynamic>>[
    {
      'name': 'tags',
      'title': 'Thẻ',
      'schema': {
        'properties': {
          'name': {'type': 'string', 'maxLength': 500},
          'color': {
            'type': 'string',
            'default': '#64748B',
            'pattern': r'^#[0-9a-fA-F]{6}$',
          },
        },
      },
    },
    {
      'name': 'budgets',
      'title': 'Ngân sách',
      'schema': {
        'properties': {
          'category_id': {
            'anyOf': [
              {'type': 'integer'},
              {'type': 'null'},
            ],
          },
          'pillar': {
            'anyOf': [
              {
                'type': 'string',
                'enum': ['needs', 'wants'],
              },
              {'type': 'null'},
            ],
          },
          'month_year': {'type': 'string', 'format': 'date'},
          'limit_amount': {'type': 'number', 'exclusiveMinimum': 0},
          'alert_threshold_percent': {
            'type': 'integer',
            'default': 80,
            'minimum': 1,
            'maximum': 100,
          },
        },
      },
    },
    {
      'name': 'categories',
      'title': 'Danh mục',
      'schema': {
        'properties': {
          'name': {'type': 'string'},
        },
      },
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> resources() async => catalog;
  @override
  Future<Map<String, dynamic>> page(String resource, {int offset = 0}) async =>
      {'items': records, 'total': records.length};
  @override
  Future<List<Map<String, dynamic>>> references(String resource) async => [];
  @override
  String key(String resource, Map<String, dynamic> record) => '${record['id']}';
  @override
  Future<Map<String, dynamic>> get(String resource, String key) async =>
      records.first;
  @override
  Future<void> save(
    String resource,
    Map<String, dynamic> values, {
    String? key,
  }) async {
    saved = values;
    savedKey = key;
  }

  @override
  Future<void> delete(String resource, String key) async {
    deleted = true;
    records.clear();
  }
}
