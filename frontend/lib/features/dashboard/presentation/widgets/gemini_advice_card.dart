import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class GeminiAdviceCard extends StatelessWidget {
  const GeminiAdviceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return KakeiboCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Gemini icon and Zen AI badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primaryForestGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lời khuyên Kakeibo từ Gemini',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textCharcoal,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tối ưu phong bao • Vừa cập nhật',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5EBDD),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Zen\nAI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E5B42),
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Insight items
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6FAF7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: Color(0xFFD96B43),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textCharcoal,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(text: 'Phong bao '),
                            TextSpan(
                              text: 'Mong muốn (Wants)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB64F2D),
                              ),
                            ),
                            TextSpan(text: ' đang chiếm tới '),
                            TextSpan(
                              text: '38%',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            TextSpan(
                              text:
                                  ' tổng chi tuần qua (chủ yếu là gọi trà sữa & ăn ngoài).',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.eco_outlined,
                        size: 16,
                        color: AppTheme.primaryForestGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textCharcoal,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: 'Đề xuất an tâm: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text:
                                  'Giảm 3 bữa ăn ngoài từ nay đến ngày 20/11 (tiết kiệm ',
                            ),
                            TextSpan(
                              text: '~450.000 ₫',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryForestGreen,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ') và hoãn nâng cấp tai nghe sang tháng tới sẽ giúp bạn duy trì số dư an toàn ',
                            ),
                            TextSpan(
                              text: '+1.800.000 ₫',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryForestGreen,
                              ),
                            ),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tỷ trọng 4 Trụ cột Kakeibo tuần này
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Tỷ trọng 4 Trụ cột Kakeibo tuần này',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textCharcoal,
                ),
              ),
              Text(
                'Cần tái cân bằng',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB64F2D),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 7,
              child: Row(
                children: const [
                  Expanded(flex: 42, child: ColoredBox(color: Color(0xFF285B45))),
                  SizedBox(width: 2),
                  Expanded(flex: 38, child: ColoredBox(color: Color(0xFFD96B43))),
                  SizedBox(width: 2),
                  Expanded(flex: 14, child: ColoredBox(color: Color(0xFF76CBB2))),
                  SizedBox(width: 2),
                  Expanded(flex: 6, child: ColoredBox(color: Color(0xFFC4CDC7))),
                ],
              ),
            ),
          ),

          const SizedBox(height: 7),

          // Legend for 4 pillars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniLegend(const Color(0xFF285B45), 'Thiết yếu 42%'),
              _buildMiniLegend(const Color(0xFFD96B43), 'Sở thích 38%'),
              _buildMiniLegend(const Color(0xFF76CBB2), 'Trí tuệ 14%'),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons: [Áp dụng kế hoạch này] & [Hỏi Gemini]
          Row(
            children: [
              Expanded(
                flex: 6,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã cập nhật mục tiêu cắt giảm vào ngân sách tuần!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text(
                    'Áp dụng kế hoạch này',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryForestGreen,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.auto_awesome,
                                  color: AppTheme.primaryForestGreen,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Trợ lý Gemini Tài Chính',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Tôi có thể giúp bạn tối ưu từng phong bao chi tiêu, gợi ý thực đơn nấu ăn tiết kiệm hoặc lên kế hoạch mua sắm thông minh cho cuối tuần.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Đặt câu hỏi cho Gemini...',
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.send,
                                    color: AppTheme.primaryForestGreen,
                                  ),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text(
                    'Hỏi Gemini',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryForestGreen,
                    backgroundColor: const Color(0xFFEAF1EB),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 7, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
