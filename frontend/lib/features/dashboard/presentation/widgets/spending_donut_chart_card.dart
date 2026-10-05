import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class SpendingDonutChartCard extends StatelessWidget {
  final List<String> names;
  final List<num> shares;
  final List<Color> colors;
  final double totalExpense;
  final String totalLabel;

  const SpendingDonutChartCard({
    required this.names,
    required this.shares,
    required this.colors,
    required this.totalExpense,
    this.totalLabel = 'Tổng chi trong kỳ',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return KakeiboCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.incomplete_circle,
                size: 19,
                color: AppTheme.primaryForestGreen,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Phân bổ chi tiêu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Phân bổ chi tiêu'),
                    content: const Text(
                      'Tỷ lệ được tính từ các giao dịch chi tiêu trong kỳ đã chọn. Chuyển tiền giữa các ví không được tính vào chi tiêu.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 210,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(180),
                  painter: _DonutPainter(shares: shares, colors: colors),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalLabel,
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatVnd(totalExpense),
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryForestGreen,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (totalExpense == 0)
                      const Text(
                        'Chưa có chi tiêu',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: List.generate(
              names.length,
              (i) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 9, color: colors[i]),
                  const SizedBox(width: 5),
                  Text(
                    names[i],
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<num> shares;
  final List<Color> colors;
  _DonutPainter({required this.shares, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -1.5708;
    if (shares.isEmpty) {
      canvas.drawArc(
        rect.deflate(10),
        start,
        6.28318,
        false,
        Paint()
          ..color = AppTheme.borderLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17,
      );
      return;
    }
    for (var i = 0; i < shares.length; i++) {
      final sweep = 6.28318 * shares[i] / 100;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect.deflate(10),
        start,
        (sweep - .035).clamp(0, 6.28318),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.shares != shares || oldDelegate.colors != colors;
}
