import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class PillarImpactCard extends StatelessWidget {
  const PillarImpactCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.eco_outlined,
              size: 20,
              color: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tác động phong bao Kakeibo',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                const SizedBox(height: 3),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textCharcoal,
                      height: 1.45,
                    ),
                    children: [
                      TextSpan(text: 'Sau 2 khoản chi này ('),
                      TextSpan(
                        text: '-100.000 ₫',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: '), phong bao '),
                      TextSpan(
                        text: 'Mong muốn (Wants)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB64F2D),
                        ),
                      ),
                      TextSpan(text: ' còn lại '),
                      TextSpan(
                        text: '165.000 ₫',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text:
                            ' cho đến Chủ Nhật. Bạn đang kiểm soát chi tiêu rất chánh niệm!',
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

class DailySpendingLimitGaugeCard extends StatelessWidget {
  const DailySpendingLimitGaugeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Row(
        children: [
          // Circular 70% Progress indicator
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    value: 0.70,
                    strokeWidth: 4.5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Color(0xFFE2EBE5),
                    color: Color(0xFF285B45),
                  ),
                ),
                const Text(
                  '70%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textCharcoal,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Details
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hạn mức chi tiêu hôm nay',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textCharcoal,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Đã dùng 315.000 ₫ / 450.000 ₫',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),

          // Remaining Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Còn 135.000 ₫',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryForestGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
