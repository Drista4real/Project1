import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/budget/cubit/envelope_form_cubit.dart';
import 'package:project_one/features/budget/models/envelope_pillar.dart';
import 'package:project_one/features/budget/services/category_envelopes_service.dart';
import '../../helpers/envelope_memory_repository.dart';

void main() {
  final month = DateTime(2026, 10);
  late EnvelopeMemoryRepository repo;
  late CategoryEnvelopesService service;
  setUp(() async {
    repo = EnvelopeMemoryRepository();
    service = CategoryEnvelopesService(repo);
    await service.rebalance(await service.load(month), 1000, [50, 25, 15, 10]);
    await service.saveCategory(
      data: await service.load(month),
      name: 'Ăn',
      pillar: EnvelopePillar.needs,
      limit: '400',
    );
  });

  test('over-allocation is rejected before creating a category', () async {
    final before = repo.tables['budgets']!.map(Map.of).toList();
    await expectLater(
      service.saveCategory(
        data: await service.load(month),
        name: 'Nhà',
        pillar: EnvelopePillar.needs,
        limit: '101',
      ),
      throwsException,
    );
    expect(repo.tables['categories'], hasLength(1));
    expect(repo.tables['budgets'], before);
  });

  test('exact capacity and replacing own limit are allowed', () async {
    await service.saveCategory(
      data: await service.load(month),
      name: 'Nhà',
      pillar: EnvelopePillar.needs,
      limit: '100',
    );
    final data = await service.load(month);
    await service.saveCategory(
      data: data,
      category: data.categories.last,
      name: 'Nhà',
      pillar: EnvelopePillar.needs,
      limit: '100',
    );
    expect(repo.tables['categories'], hasLength(2));
  });

  test(
    'moving a category checks destination before changing metadata',
    () async {
      final data = await service.load(month);
      await expectLater(
        service.saveCategory(
          data: data,
          category: data.categories.single,
          name: 'Đổi tên',
          pillar: EnvelopePillar.wants,
          limit: '400',
        ),
        throwsException,
      );
      expect(repo.tables['categories']!.single['pillar'], 'needs');
      expect(repo.tables['categories']!.single['name'], 'Ăn');
    },
  );

  test(
    'rebalance rejects shrinking or zeroing a funded pillar before writes',
    () async {
      final before = repo.tables['budgets']!.map(Map.of).toList();
      for (final shares in [
        [30, 45, 15, 10],
        [0, 75, 15, 10],
      ]) {
        await expectLater(
          service.rebalance(await service.load(month), 1000, shares),
          throwsException,
        );
        expect(repo.tables['budgets'], before);
      }
    },
  );

  test('monthly cap applies without configured pillar caps', () async {
    repo.tables['budgets']!.removeWhere((b) => b['pillar'] != null);
    await expectLater(
      service.saveCategory(
        data: await service.load(month),
        name: 'Nhà',
        pillar: EnvelopePillar.wants,
        limit: '601',
      ),
      throwsException,
    );
  });

  test('save reloads caps changed since the sheet opened', () async {
    final cubit = EnvelopeFormCubit(service, await service.load(month));
    addTearDown(cubit.close);
    final parent = repo.tables['budgets']!.firstWhere(
      (b) => b['pillar'] == 'needs',
    );
    parent['limit_amount'] = '400';
    await cubit.saveCategory(
      name: 'Nhà',
      pillar: EnvelopePillar.needs,
      limit: '1',
    );
    expect(cubit.state.saved, isFalse);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.error, contains('vượt phong bao'));
    expect(repo.tables['categories'], hasLength(1));
  });
}
