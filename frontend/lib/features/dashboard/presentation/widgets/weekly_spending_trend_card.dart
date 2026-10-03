import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class WeeklySpendingTrendCard extends StatelessWidget {
  const WeeklySpendingTrendCard({super.key});

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
                'Xu hướng trong tuần',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  size: 16,
                  color: AppTheme.primaryForestGreen,
                ),
              ),
            ],
          ),
          const Text(
            'Mức chi tiêu bình quân ngày theo tuần gần nhất',
            style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 135,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                const heights = [28.0, 36.0, 24.0, 48.0, 56.0, 80.0, 80.0];
                final weekend = i > 4;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (weekend)
                        Text(
                          i == 5 ? '1.15m' : '1.28m',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: Color(0xFF9E3E26),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                      const SizedBox(height: 4),
                      Container(
                        height: heights[i],
                        width: 28,
                        decoration: BoxDecoration(
                          color: weekend
                              ? const Color(0xFF9E3E26)
                              : const Color(0xFFE3E8E3),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i],
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: weekend ? FontWeight.w700 : FontWeight.w500,
                          color: weekend
                              ? const Color(0xFF9E3E26)
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡', style: TextStyle(fontSize: 14)),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cuối tuần chi tiêu cao hơn 35% so với ngày trong tuần.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textCharcoal,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Bạn có thể tự chuẩn bị bữa tối tại nhà vào Thứ Bảy để duy trì dòng tiền thảnh thơi.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
