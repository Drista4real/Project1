import 'package:flutter/material.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';
import '../models/transaction_draft.dart';

class TransactionReviewCard extends StatelessWidget {
  const TransactionReviewCard({
    required this.item,
    required this.accountName,
    required this.categoryName,
    required this.pillar,
    required this.onEdit,
    required this.onDismissed,
    this.enabled = true,
    this.budgetWarning,
    super.key,
  });

  final ReviewTransaction item;
  final String accountName, categoryName, pillar;
  final String? budgetWarning;
  final VoidCallback onEdit, onDismissed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final income = item.type == 'income';
    final color = income
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFB59C)
        : const Color(0xFFA54729);
    final date = item.date;
    final today = DateTime.now();
    final dateText =
        date.year == today.year &&
            date.month == today.month &&
            date.day == today.day
        ? 'hôm nay'
        : '${date.day}/${date.month}/${date.year}';
    final colors = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('draft-${item.id}'),
      direction: enabled ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: colors.onErrorContainer),
      ),
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onEdit : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sửa giao dịch',
                      onPressed: enabled ? onEdit : null,
                      icon: const Icon(Icons.edit_outlined, size: 20),
                    ),
                  ],
                ),
                Text(
                  item.amount == null
                      ? 'Chưa có số tiền'
                      : '${income ? '+' : '−'}${formatVnd(item.amount!)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$categoryName · ${pillar.split(' (').first}',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$accountName · $dateText',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (!item.canSave || budgetWarning != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: colors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          budgetWarning ??
                              (item.accountId == null
                                  ? 'Chưa có số dư. Hãy thiết lập kế hoạch tháng.'
                                  : 'Cần bổ sung thông tin trước khi lưu.'),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.draft.warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    item.draft.warnings.join(' '),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
