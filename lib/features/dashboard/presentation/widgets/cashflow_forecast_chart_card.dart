import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class CashflowForecastChartCard extends StatelessWidget {
  const CashflowForecastChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    return KakeiboCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Biến động số dư khả dụng',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Darts NeuralForecast • LightGBM v3.4',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppTheme.textMuted.withAlpha(220),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.trending_down,
                      size: 14,
                      color: AppTheme.primaryForestGreen,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '14 Ngày tới',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryForestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Custom Painted Chart
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _CashflowChartPainter(),
            ),
          ),

          const SizedBox(height: 14),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                const Color(0xFF2D5A43),
                'Thực tế',
                isDashed: false,
              ),
              const SizedBox(width: 14),
              _buildLegendItem(
                const Color(0xFF9E3E26),
                'Dự báo LightGBM',
                isDashed: true,
              ),
              const SizedBox(width: 14),
              _buildLegendItem(
                const Color(0xFF8FE3CB),
                'Ngưỡng 2.000.000 ₫',
                isBox: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    Color color,
    String label, {
    bool isDashed = false,
    bool isBox = false,
  }) {
    Widget symbol;
    if (isBox) {
      symbol = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (isDashed) {
      symbol = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 5, height: 2.5, color: color),
          const SizedBox(width: 2),
          Container(width: 5, height: 2.5, color: color),
        ],
      );
    } else {
      symbol = Container(width: 12, height: 2.5, color: color);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        symbol,
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CashflowChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw baseline 0đ
    final zeroLineY = h * 0.72;
    final gridPaint = Paint()
      ..color = const Color(0xFFE2EAE3)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, zeroLineY), Offset(w, zeroLineY), gridPaint);

    // Mốc 0đ label
    const textStyleMuted = TextStyle(fontSize: 8.5, color: Color(0xFF9AA7A0));
    final tp0 = TextPainter(
      text: const TextSpan(text: 'Mốc 0 đ', style: textStyleMuted),
      textDirection: TextDirection.ltr,
    )..layout();
    tp0.paint(canvas, Offset(0, zeroLineY - 14));

    // Ngưỡng an toàn 2tr
    final safeY = h * 0.60;
    final safePaint = Paint()
      ..color = const Color(0xFF90E0C8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(w * 0.55, safeY), Offset(w, safeY), safePaint);

    final tpSafe = TextPainter(
      text: const TextSpan(
        text: 'Ngưỡng an toàn (2 Tr)',
        style: TextStyle(
          fontSize: 8,
          color: Color(0xFF45927B),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpSafe.paint(canvas, Offset(w - tpSafe.width, safeY - 13));

    // Dates at bottom
    final dateLabels = [
      (0.04, '10/11'),
      (0.48, '14/11 (Nay)'),
      (0.78, '20/11 (!)'),
      (0.92, '28/11'),
    ];
    for (final dl in dateLabels) {
      final isDeficit = dl.$2.contains('20/11');
      final tpDate = TextPainter(
        text: TextSpan(
          text: dl.$2,
          style: TextStyle(
            fontSize: 9,
            fontWeight: dl.$2.contains('Nay') || isDeficit
                ? FontWeight.w700
                : FontWeight.w500,
            color: isDeficit
                ? const Color(0xFF9E3E26)
                : const Color(0xFF889790),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpDate.paint(canvas, Offset(w * dl.$1 - tpDate.width / 2, h - 16));
    }

    // Historical Points (Up to 14/11 - Nay)
    final p0 = Offset(w * 0.05, h * 0.56);
    final p1 = Offset(w * 0.28, h * 0.38);
    final pToday = Offset(w * 0.45, h * 0.43);

    // Green shaded area under historical
    final areaPath = Path()
      ..moveTo(p0.dx, zeroLineY)
      ..lineTo(p0.dx, p0.dy)
      ..quadraticBezierTo(w * 0.20, h * 0.38, p1.dx, p1.dy)
      ..quadraticBezierTo(w * 0.38, h * 0.39, pToday.dx, pToday.dy)
      ..lineTo(pToday.dx, zeroLineY)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2D5A43).withAlpha(50),
          const Color(0xFF2D5A43).withAlpha(5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(areaPath, areaPaint);

    // Historical line (Solid Green)
    final histPath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(w * 0.20, h * 0.38, p1.dx, p1.dy)
      ..quadraticBezierTo(w * 0.38, h * 0.39, pToday.dx, pToday.dy);

    final histPaint = Paint()
      ..color = const Color(0xFF2D5A43)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(histPath, histPaint);

    // Draw dots on historical line
    final dotPaint = Paint()..color = const Color(0xFF2D5A43);
    canvas.drawCircle(p0, 3.5, dotPaint);
    canvas.drawCircle(p1, 3.5, dotPaint);

    // Today marker with pill badge: "Hôm nay: 12.45 Tr"
    canvas.drawCircle(pToday, 4.5, Paint()..color = const Color(0xFF9E3E26));
    canvas.drawCircle(pToday, 2.5, Paint()..color = Colors.white);

    // Forecast line (Dashed red/coral falling down below 0 to -500k)
    final pDeficit = Offset(w * 0.78, h * 0.78);
    final pEnd = Offset(w * 0.94, h * 0.81);

    final forecastPath = Path()
      ..moveTo(pToday.dx, pToday.dy)
      ..cubicTo(
        w * 0.58,
        h * 0.48,
        w * 0.68,
        h * 0.72,
        pDeficit.dx,
        pDeficit.dy,
      )
      ..quadraticBezierTo(w * 0.86, h * 0.82, pEnd.dx, pEnd.dy);

    _drawDashedPath(canvas, forecastPath, const Color(0xFF9E3E26), 2.8, 5, 4);

    // Deficit red shaded area
    final deficitArea = Path()
      ..moveTo(w * 0.69, zeroLineY)
      ..quadraticBezierTo(w * 0.73, h * 0.75, pDeficit.dx, pDeficit.dy)
      ..quadraticBezierTo(w * 0.86, h * 0.82, pEnd.dx, pEnd.dy)
      ..lineTo(pEnd.dx, zeroLineY)
      ..close();

    final deficitAreaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF9E3E26).withAlpha(10),
          const Color(0xFF9E3E26).withAlpha(60),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(deficitArea, deficitAreaPaint);

    // Dot at 20/11
    canvas.drawCircle(pDeficit, 4, Paint()..color = const Color(0xFF9E3E26));
    canvas.drawCircle(pDeficit, 2, Paint()..color = Colors.white);

    // Badge "-500.000 đ"
    _drawBadge(
      canvas,
      Offset(pDeficit.dx, pDeficit.dy - 16),
      '-500.000 đ',
      const Color(0xFFFFDCD0),
      const Color(0xFF9E3E26),
    );

    // Badge "Hôm nay: 12.45 Tr"
    _drawBadge(
      canvas,
      Offset(pToday.dx, pToday.dy - 24),
      'Hôm nay: 12.45 Tr',
      const Color(0xFF2D5A43),
      Colors.white,
    );
  }

  void _drawBadge(
    Canvas canvas,
    Offset center,
    String text,
    Color bg,
    Color textColor,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 12,
        height: tp.height + 6,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = bg);
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Color color,
    double strokeWidth,
    double dashWidth,
    double dashSpace,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
