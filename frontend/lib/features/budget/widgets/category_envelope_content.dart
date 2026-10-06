import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import '../models/category_envelope_data.dart';
import '../models/envelope_pillar.dart';
import 'envelope_banner.dart';
import 'envelope_pillar_group.dart';
import 'envelope_toolbar.dart';
import 'pillar_allocation_card.dart';

class CategoryEnvelopeContent extends StatelessWidget {
  const CategoryEnvelopeContent({
    super.key,
    required this.data,
    required this.search,
    required this.onSearch,
    required this.onMonth,
    required this.onAdd,
    required this.onRebalance,
    required this.onEdit,
    required this.onAction,
    required this.onDisable,
    required this.onAdvanced,
  });
  final CategoryEnvelopeData data;
  final TextEditingController search;
  final VoidCallback onSearch, onRebalance;
  final ValueChanged<String> onAdvanced;
  final ValueChanged<int> onMonth;
  final ValueChanged<EnvelopePillar> onAdd;
  final ValueChanged<FinanceRecord> onEdit;
  final void Function(FinanceRecord, String) onAction;
  final Future<void> Function(FinanceRecord) onDisable;

  @override
  Widget build(BuildContext context) {
    final query = search.text.trim().toLowerCase();
    final categories = data.expenses
        .where((c) => '${c['name']}'.toLowerCase().contains(query))
        .toList();
    final unassigned = categories
        .where((c) => EnvelopePillar.fromKey(c['pillar']) == null)
        .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EnvelopeBanner(),
            EnvelopeToolbar(
              month: data.month,
              search: search,
              onSearch: onSearch,
              onMonth: onMonth,
              onAdd: () => onAdd(EnvelopePillar.needs),
              onRebalance: onRebalance,
            ),
            const SizedBox(height: 18),
            PillarAllocationCard(data: data),
            if (query.isNotEmpty && categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text('Không tìm thấy danh mục phù hợp.'),
              ),
            for (final pillar in EnvelopePillar.values)
              if (query.isEmpty ||
                  categories.any((c) => c['pillar'] == pillar.key))
                EnvelopePillarGroup(
                  data: data,
                  pillar: pillar,
                  categories: categories
                      .where((c) => c['pillar'] == pillar.key)
                      .toList(),
                  onEdit: onEdit,
                  onAdd: () => onAdd(pillar),
                  onAction: onAction,
                  onDisable: onDisable,
                ),
            if (unassigned.isNotEmpty)
              EnvelopePillarGroup(
                data: data,
                categories: unassigned,
                onEdit: onEdit,
                onAdd: () => onAdd(EnvelopePillar.needs),
                onAction: onAction,
                onDisable: onDisable,
              ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EnvelopeStyle.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 20,
                    color: EnvelopeStyle.muted,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chạm danh mục để sửa hạn mức. Vuốt sang trái để tắt phong bao tháng này.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: EnvelopeStyle.muted,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Quản lý nâng cao',
              onSelected: onAdvanced,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'categories',
                  child: Text('Danh mục thu nhập & tùy chọn nâng cao'),
                ),
                PopupMenuItem(
                  value: 'budgets',
                  child: Text('Hạn mức tổng & tùy chọn ngân sách'),
                ),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: EnvelopeStyle.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Quản lý danh mục & ngân sách nâng cao',
                        style: TextStyle(
                          fontSize: 11,
                          color: EnvelopeStyle.primary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: EnvelopeStyle.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
