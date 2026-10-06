import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import '../models/category_envelope_data.dart';
import '../models/envelope_pillar.dart';

class CategoryEnvelopesService {
  const CategoryEnvelopesService(this.repository);
  final ManagementRepository repository;

  Future<CategoryEnvelopeData> load(DateTime month) async {
    final lists = await Future.wait([
      repository.references('categories'),
      repository.references('budgets'),
    ]);
    return CategoryEnvelopeData(month, lists[0], lists[1]);
  }

  Future<void> saveCategory({
    required CategoryEnvelopeData data,
    required String name,
    required EnvelopePillar pillar,
    required String? limit,
    FinanceRecord? category,
  }) async {
    FinanceRecord? created;
    FinanceRecord? previous;
    if (category == null) {
      created = await repository.create('categories', {
        'name': name,
        'pillar': pillar.key,
        'is_income': false,
        'color': '#${pillar.color.toARGB32().toRadixString(16).substring(2)}',
        'icon': 'category',
      });
      category = created;
    } else if (category['user_id'] != null) {
      previous = data.categories.firstWhere(
        (c) => c['id'] == category!['id'],
        orElse: () => category!,
      );
      await repository.save('categories', {
        'name': name,
        'pillar': pillar.key,
      }, key: repository.key('categories', category));
    }
    try {
      await saveLimit(data, category['id'] as int, limit);
    } catch (error) {
      if (created != null) {
        try {
          await repository.delete(
            'categories',
            repository.key('categories', created),
          );
        } catch (_) {
          throw Exception(
            'Danh mục đã được tạo nhưng hạn mức chưa lưu. Tải lại danh sách và chỉnh sửa để tiếp tục.',
          );
        }
      } else if (previous != null) {
        try {
          await repository.save('categories', {
            'name': previous['name'],
            'pillar': previous['pillar'],
          }, key: repository.key('categories', previous));
        } catch (_) {
          throw Exception(
            'Thông tin danh mục đã đổi nhưng hạn mức chưa lưu. Tải lại danh sách để kiểm tra trước khi thử lại.',
          );
        }
      }
      rethrow;
    }
  }

  Future<void> saveLimit(
    CategoryEnvelopeData data,
    int categoryId,
    String? limit,
  ) async {
    final existing = data.budgets
        .where((b) => b['category_id'] == categoryId)
        .toList();
    if (limit == null) {
      for (final record in existing) {
        await repository.delete('budgets', repository.key('budgets', record));
      }
      return;
    }
    final values = {
      'category_id': categoryId,
      'pillar': null,
      'month_year': data.monthKey,
      'limit_amount': limit,
    };
    await repository.save(
      'budgets',
      values,
      key: existing.isEmpty ? null : repository.key('budgets', existing.first),
    );
  }

  Future<void> rebalance(
    CategoryEnvelopeData data,
    int total,
    List<int> percentages,
  ) async {
    if (total <= 0 ||
        percentages.length != 4 ||
        percentages.any((p) => p < 0 || p > 100) ||
        percentages.fold(0, (a, b) => a + b) != 100) {
      throw ArgumentError(
        'Tổng phân bổ phải bằng 100% và ngân sách phải lớn hơn 0.',
      );
    }
    // Keep currency precision at two decimal places; assign rounding to the
    // final nonzero pillar so the sum always matches the monthly budget.
    var remaining = total * 100;
    final last = percentages.lastIndexWhere((p) => p > 0);
    for (var i = 0; i < 4; i++) {
      final pillar = EnvelopePillar.values[i];
      final existing = data.budgets
          .where((b) => b['category_id'] == null && b['pillar'] == pillar.key)
          .toList();
      if (percentages[i] == 0) {
        for (final record in existing) {
          await repository.delete('budgets', repository.key('budgets', record));
        }
        continue;
      }
      final cents = i == last ? remaining : total * percentages[i];
      remaining -= cents;
      await repository.save(
        'budgets',
        {
          'category_id': null,
          'pillar': pillar.key,
          'month_year': data.monthKey,
          'limit_amount': (cents / 100).toStringAsFixed(2),
        },
        key: existing.isEmpty
            ? null
            : repository.key('budgets', existing.first),
      );
    }
    final overall = data.budgetFor();
    await repository.save('budgets', {
      'category_id': null,
      'pillar': null,
      'month_year': data.monthKey,
      'limit_amount': '$total',
    }, key: overall == null ? null : repository.key('budgets', overall));
  }
}
