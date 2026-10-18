import 'package:flutter/material.dart';
import 'package:project_one/core/theme/app_theme.dart';
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
        ? AppTheme.primaryForestGreen
        : const Color(0xFFAB3C16);
    final date = item.date;
    final today = DateTime.now();
    final dateText =
        date.year == today.year &&
            date.month == today.month &&
            date.day == today.day
        ? 'hôm nay'
        : '${date.day}/${date.month}/${date.year}';
    return Dismissible(
      key: ValueKey('draft-${item.id}'),
      direction: enabled ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.expenseCoral,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: income
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    income
                        ? Icons.savings_outlined
                        : Icons.receipt_long_outlined,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: enabled ? onEdit : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _Meta(
                              icon: Icons.account_balance_wallet_outlined,
                              text: accountName,
                            ),
                            _Meta(icon: Icons.access_time, text: dateText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.amount == null
                          ? 'Chưa rõ tiền'
                          : '${income ? '+' : '−'}${formatVnd(item.amount!)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Chờ xác nhận',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sửa giao dịch',
                      onPressed: enabled ? onEdit : null,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: Text(pillar, style: const TextStyle(fontSize: 11)),
                  avatar: Icon(
                    Icons.circle,
                    size: 7,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  backgroundColor: const Color(0xFFEAF1EC),
                  side: BorderSide.none,
                  onPressed: enabled ? onEdit : null,
                ),
                ActionChip(
                  label: Text(
                    categoryName,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                  onPressed: enabled ? onEdit : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  item.canSave && budgetWarning == null
                      ? Icons.verified_outlined
                      : Icons.info_outline,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    budgetWarning ??
                        (item.canSave
                            ? 'Kiểm tra trước khi lưu'
                            : item.accountId == null
                            ? 'Chưa có ví phù hợp — chọn ví để lưu'
                            : 'Cần bổ sung thông tin'),
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ),
              ],
            ),
            if (item.draft.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.draft.warnings.join(' '),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
