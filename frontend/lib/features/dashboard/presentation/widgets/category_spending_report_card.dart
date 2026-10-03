import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class CategorySpendingReportCard extends StatelessWidget {
  final List<String> names;
  final List<int> shares;
  final List<int> amounts;
  final List<Color> colors;

  const CategorySpendingReportCard({
    required this.names,
    required this.shares,
    required this.amounts,
    required this.colors,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return KakeiboCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hạng mục chi nhiều nhất',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${names.length} mục lớn',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CategoryReportRow(
            name: 'Ăn uống & Cà phê',
            subtitle: 'Cần thiết & Gặp gỡ',
            amount: amounts[0],
            share: shares[0],
            color: colors[0],
            icon: Icons.restaurant,
          ),
          _CategoryReportRow(
            name: 'Nhà ở & Hóa đơn',
            subtitle: 'Cố định hàng tháng',
            amount: amounts[1],
            share: shares[1],
            color: colors[1],
            icon: Icons.home_outlined,
          ),
          _CategoryReportRow(
            name: 'Mua sắm cá nhân',
            subtitle: 'Ngẫu hứng & Sở thích',
            amount: amounts[2],
            share: shares[2],
            color: colors[2],
            icon: Icons.shopping_bag_outlined,
          ),
          _CategoryReportRow(
            name: 'Di chuyển & Xăng xe',
            subtitle: 'Đi lại công việc',
            amount: amounts[3],
            share: shares[3],
            color: colors[3],
            icon: Icons.local_gas_station_outlined,
          ),
          _CategoryReportRow(
            name: 'Giải trí & Sở thích',
            subtitle: 'Sách, phim & thư giãn',
            amount: amounts[4],
            share: shares[4],
            color: colors[4],
            icon: Icons.movie_outlined,
          ),
        ],
      ),
    );
  }
}

class _CategoryReportRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final num amount;
  final int share;
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
                  '$share%',
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
        KakeiboProgress(value: share / 50, color: color),
      ],
    ),
  );
}
