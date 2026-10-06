import 'memory_management_repository.dart';

class SettingsRepository extends MemoryManagementRepository {
  @override
  Future<Map<String, dynamic>> get(String resource, String key) async => {
    'full_name': 'An',
    'payroll_day': 25,
  };

  @override
  Future<List<Map<String, dynamic>>> references(String resource) async =>
      resource == 'tags'
      ? [
          {'id': 1, 'name': 'dulich'},
        ]
      : [];
}
