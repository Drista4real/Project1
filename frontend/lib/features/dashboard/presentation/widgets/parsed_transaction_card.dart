import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class ParsedTransactionItem {
  String title;
  double amount;
  String accountType; // 'Tiền mặt' or 'Vietcombank' or bank name
  String timeString;
  String pillar; // 'Thiết yếu(Needs)', 'Mong muốn(Wants)', etc.
  String subCategory; // 'Ăn trưa công sở', 'Đồ uống & Xã hội', etc.
  Color color;
  IconData icon;
  String? badgeText; // 'Khớp quy chuẩn', '85% ngân sách tuần'
  bool isWarning;

  ParsedTransactionItem({
    required this.title,
    required this.amount,
    required this.accountType,
    required this.timeString,
    required this.pillar,
    required this.subCategory,
    required this.color,
    required this.icon,
    this.badgeText,
    this.isWarning = false,
  });
}

class ParsedTransactionCard extends StatelessWidget {
  final ParsedTransactionItem item;
  final int index;
  final VoidCallback onDismissed;

  const ParsedTransactionCard({
    required this.item,
    required this.index,
    required this.onDismissed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('${item.title}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon tile
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: const Color(0xFFB64F2D),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Sub metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textCharcoal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            item.accountType == 'Tiền mặt'
                                ? Icons.payments_outlined
                                : Icons.account_balance_outlined,
                            size: 13,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.accountType,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.timeString,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-${formatVnd(item.amount)}',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB64F2D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.accountType == 'Tiền mặt'
                          ? 'Chi phí tự động'
                          : 'Đã trừ tài khoản',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Chips row: [Pillar dropdown] [Subcategory chip] [Right badge]
            Row(
              children: [
                // Pillar Dropdown Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.pillar.contains('Needs')
                        ? const Color(0xFFEAF5EE)
                        : const Color(0xFFFFECE5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 7,
                        color: item.pillar.contains('Needs')
                            ? AppTheme.primaryForestGreen
                            : const Color(0xFFB64F2D),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.pillar,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: item.pillar.contains('Needs')
                              ? AppTheme.primaryForestGreen
                              : const Color(0xFFB64F2D),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Subcategory
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    item.subCategory,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                ),

                const Spacer(),

                // Right status badge
                if (item.badgeText != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isWarning
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 13,
                        color: item.isWarning
                            ? const Color(0xFFB64F2D)
                            : AppTheme.primaryForestGreen,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        item.badgeText!,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: item.isWarning
                              ? const Color(0xFFB64F2D)
                              : AppTheme.primaryForestGreen,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
