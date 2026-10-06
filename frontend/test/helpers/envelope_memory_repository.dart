import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'memory_management_repository.dart';

class EnvelopeMemoryRepository extends MemoryManagementRepository {
  final tables = <String, List<FinanceRecord>>{
    'categories': [],
    'budgets': [],
    'transactions': [],
  };
  bool failBudgetSave = false;
  bool failLoad = false;
  int nextId = 100;

  @override
  Future<FinanceRecord> page(String resource, {int offset = 0}) async => {
    'items': tables[resource]!.skip(offset).take(30).toList(),
    'total': tables[resource]!.length,
  };

  @override
  Future<List<FinanceRecord>> references(String resource) async {
    if (failLoad) throw Exception('Không thể tải dữ liệu');
    return tables[resource]!.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<FinanceRecord> create(String resource, FinanceRecord values) async {
    if (resource == 'budgets' && failBudgetSave) {
      throw Exception('Không thể lưu hạn mức');
    }
    final record = {'id': nextId++, 'user_id': 'owner', ...values};
    tables[resource]!.add(record);
    return Map<String, dynamic>.from(record);
  }

  @override
  Future<void> save(
    String resource,
    FinanceRecord values, {
    String? key,
  }) async {
    if (resource == 'budgets' && failBudgetSave) {
      throw Exception('Không thể lưu hạn mức');
    }
    if (key == null) {
      await create(resource, values);
    } else {
      final record = tables[resource]!.firstWhere((r) => '${r['id']}' == key);
      record.addAll(values);
    }
  }

  @override
  Future<void> delete(String resource, String key) async {
    tables[resource]!.removeWhere((r) => '${r['id']}' == key);
  }
}
