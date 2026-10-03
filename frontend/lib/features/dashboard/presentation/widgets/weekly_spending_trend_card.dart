import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'kakeibo_ui.dart';

class WeeklySpendingTrendCard extends StatelessWidget {
  const WeeklySpendingTrendCard({
    super.key,
    this.amounts = const [0, 0, 0, 0, 0, 0, 0],
  });
  final List<double> amounts;
  @override
  Widget build(BuildContext context) {
    final maximum = amounts.fold(0.0, (a, b) => a > b ? a : b);
    final total = amounts.fold(0.0, (sum, value) => sum + value);
    return KakeiboCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xu hướng trong tuần',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Text(
            'Chi tiêu từng ngày trong tuần được chọn',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < amounts.length; index++)
                  Expanded(
                    child: Tooltip(
                      message: formatVnd(amounts[index]),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (amounts[index] > 0)
                            FittedBox(
                              child: Text(
                                formatVnd(amounts[index]),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            width: 25,
                            height: maximum == 0
                                ? 2
                                : (amounts[index] / maximum * 90).clamp(2, 90),
                            decoration: BoxDecoration(
                              color: index > 4
                                  ? AppTheme.expenseCoral
                                  : AppTheme.primaryForestGreen,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][index],
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Bình quân: ${formatVnd(total / 7)} / ngày',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
