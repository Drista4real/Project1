import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/budget/models/envelope_pillar.dart';
import 'package:project_one/features/budget/services/category_envelopes_service.dart';
import '../../helpers/envelope_memory_repository.dart';

void main() {
  late EnvelopeMemoryRepository repository;
  late CategoryEnvelopesService service;
  final month = DateTime(2026, 10);
  setUp(() {
    repository = EnvelopeMemoryRepository();
    service = CategoryEnvelopesService(repository);
  });

  test(
    'creates category and its monthly envelope using the returned ID',
    () async {
      final data = await service.load(month);
      await service.saveCategory(
        data: data,
        name: 'Trà chiều',
        pillar: EnvelopePillar.wants,
        limit: '1000000',
      );
      final category = repository.tables['categories']!.single;
      final budget = repository.tables['budgets']!.single;
      expect(budget['category_id'], category['id']);
      expect(budget['month_year'], '2026-10-01');
      expect(category['pillar'], 'wants');
    },
  );

  test('failed envelope creation removes the newly created category', () async {
    repository.failBudgetSave = true;
    final data = await service.load(month);
    await expectLater(
      service.saveCategory(
        data: data,
        name: 'Test',
        pillar: EnvelopePillar.needs,
        limit: '100',
      ),
      throwsException,
    );
    expect(repository.tables['categories'], isEmpty);
  });

  test('failed limit update restores editable category metadata', () async {
    repository.tables['categories']!.add({
      'id': 1,
      'user_id': 'owner',
      'name': 'Tên cũ',
      'pillar': 'needs',
      'is_income': false,
    });
    final data = await service.load(month);
    repository.failBudgetSave = true;
    await expectLater(
      service.saveCategory(
        data: data,
        category: data.categories.single,
        name: 'Tên mới',
        pillar: EnvelopePillar.wants,
        limit: '500',
      ),
      throwsException,
    );
    expect(repository.tables['categories']!.single['name'], 'Tên cũ');
    expect(repository.tables['categories']!.single['pillar'], 'needs');
  });

  test(
    'system category keeps its name and pillar while budget can be changed',
    () async {
      repository.tables['categories']!.add({
        'id': 1,
        'user_id': null,
        'name': 'Ăn uống',
        'pillar': 'needs',
        'is_income': false,
      });
      final data = await service.load(month);
      await service.saveCategory(
        data: data,
        name: 'Forbidden',
        pillar: EnvelopePillar.wants,
        limit: '500',
        category: data.categories.single,
      );
      expect(repository.tables['categories']!.single['name'], 'Ăn uống');
      expect(repository.tables['categories']!.single['pillar'], 'needs');
      expect(repository.tables['budgets']!.single['limit_amount'], '500');
    },
  );

  test(
    'rebalance persists all percentages and monthly total, zero removes a pillar envelope',
    () async {
      await service.rebalance(await service.load(month), 10000001, [
        50,
        25,
        15,
        10,
      ]);
      final data = await service.load(month);
      expect(data.totalLimit, 10000001);
      expect(data.allocated, 10000001);
      expect(data.percent(EnvelopePillar.needs), 50);
      repository.tables['categories']!.add({
        'id': 1,
        'user_id': 'owner',
        'name': 'Dự phòng',
        'pillar': 'unexpected',
        'is_income': false,
      });
      repository.tables['budgets']!.add({
        'id': 10,
        'category_id': 1,
        'pillar': null,
        'month_year': '2026-10-01',
        'limit_amount': '1000000',
      });
      await service.rebalance(data, 10000001, [60, 25, 15, 0]);
      final updated = await service.load(month);
      expect(updated.budgetFor(pillar: 'unexpected'), isNull);
      expect(updated.allocated, 10000001);
      expect(updated.percent(EnvelopePillar.unexpected), 0);
      expect(updated.budgetFor(categoryId: 1)!['limit_amount'], '1000000');
      expect(repository.tables['budgets']!.length, 5);
    },
  );

  test(
    'removing an envelope only removes the selected month budgets',
    () async {
      repository.tables['budgets']!.addAll([
        {
          'id': 1,
          'category_id': 3,
          'month_year': '2026-10-01',
          'limit_amount': '100',
        },
        {
          'id': 2,
          'category_id': 3,
          'month_year': '2026-11-01',
          'limit_amount': '200',
        },
      ]);
      await service.saveLimit(await service.load(month), 3, null);
      expect(repository.tables['budgets']!.single['month_year'], '2026-11-01');
    },
  );

  test(
    'rounded initial percentages sum to 100 for uneven allocations',
    () async {
      for (var i = 0; i < 3; i++) {
        repository.tables['budgets']!.add({
          'id': i + 1,
          'category_id': null,
          'pillar': EnvelopePillar.values[i].key,
          'month_year': '2026-10-01',
          'limit_amount': '1',
        });
      }
      final data = await service.load(month);
      expect(data.roundedPercentages.fold(0, (a, b) => a + b), 100);
      expect(
        data.roundedPercentages.take(3),
        everyElement(inInclusiveRange(33, 34)),
      );
      expect(data.roundedPercentages.last, 0);
    },
  );
}
