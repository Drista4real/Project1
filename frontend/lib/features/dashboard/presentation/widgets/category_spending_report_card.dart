import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'kakeibo_ui.dart';

class CategorySpendingReportCard extends StatelessWidget {
  const CategorySpendingReportCard({
    super.key,
    required this.names,
    required this.shares,
    required this.amounts,
    required this.colors,
  });
  final List<String> names;
  final List<num> shares;
  final List<num> amounts;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => KakeiboCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hạng mục chi nhiều nhất',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        if (names.isEmpty)
          const Text('Chưa có giao dịch chi tiêu trong kỳ này.'),
        for (var index = 0; index < names.length; index++)
          _CategoryReportRow(
            name: names[index],
            subtitle: 'Tỷ lệ trong tổng chi tiêu',
            amount: amounts[index],
            share: shares[index],
            color: colors[index],
            icon: Icons.category_outlined,
          ),
      ],
    ),
  );
}

class _CategoryReportRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final num amount;
  final num share;
  final Color color;
  final IconData icon;

  const _CategoryReportRow({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.share,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatVnd(amount),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                Text(
                  '${share.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        KakeiboProgress(value: share / 100, color: color),
      ],
    ),
  );
}
