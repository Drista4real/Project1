import 'package:flutter/material.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import '../models/category_envelope_data.dart';
import '../models/envelope_pillar.dart';
import 'category_envelope_tile.dart';

class EnvelopePillarGroup extends StatelessWidget {
  const EnvelopePillarGroup({
    super.key,
    required this.data,
    required this.categories,
    required this.onEdit,
    required this.onAction,
    required this.onDisable,
    required this.onAdd,
    this.pillar,
  });
  final CategoryEnvelopeData data;
  final List<FinanceRecord> categories;
  final EnvelopePillar? pillar;
  final ValueChanged<FinanceRecord> onEdit;
  final void Function(FinanceRecord, String) onAction;
  final Future<void> Function(FinanceRecord) onDisable;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: pillar?.tint ?? EnvelopeStyle.border,
              child: Text(
                pillar == null ? '?' : '${pillar!.index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: pillar?.color ?? EnvelopeStyle.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pillar?.title ?? 'Chưa phân trụ cột',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: pillar?.color ?? EnvelopeStyle.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: EnvelopeStyle.border,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${categories.length} mục',
                style: const TextStyle(fontSize: 10),
              ),
            ),
            if (pillar != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 58,
                child: Text(
                  '${data.percent(pillar!).toStringAsFixed(data.suggested ? 0 : 1).replaceAll('.0', '')}%\nHạn mức',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: pillar!.color),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        for (final category in categories)
          CategoryEnvelopeTile(
            category: category,
            pillar: pillar,
            budget: data.budgetFor(categoryId: category['id'] as int),
            onEdit: () => onEdit(category),
            onAction: (action) => onAction(category, action),
            onDisable: () => onDisable(category),
          ),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Chưa có danh mục trong phong bao này.',
              style: TextStyle(fontSize: 12, color: EnvelopeStyle.muted),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              'Thêm vào ${pillar?.shortLabel.toLowerCase() ?? 'thiết yếu'}',
            ),
            style: TextButton.styleFrom(
              backgroundColor: EnvelopeStyle.soft,
              foregroundColor: pillar?.color ?? EnvelopeStyle.primary,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
