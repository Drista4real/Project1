import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/shared/widgets/kakeibo_card.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

class CashflowForecastChartCard extends StatelessWidget {
  const CashflowForecastChartCard({
    super.key,
    this.records = const [],
    this.currentBalance = 0,
    this.days = 14,
  });
  final List<FinanceRecord> records;
  final double currentBalance;
  final int days;

  @override
  Widget build(BuildContext context) => KakeiboCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Biến động số dư khả dụng',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Hiện tại: ${formatVnd(currentBalance)}',
          style: const TextStyle(color: AppTheme.primaryForestGreen),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Chưa có dự báo được lưu trong khoảng ngày này.'),
          )
        else
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              painter: _ForecastPainter(
                records,
                currentBalance,
                days,
                DateTime.now(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            const Text(
              '● Số dư hiện tại',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.primaryForestGreen,
              ),
            ),
            const Text(
              '● Dự báo đã lưu',
              style: TextStyle(fontSize: 11, color: AppTheme.expenseCoral),
            ),
            if (records.isNotEmpty)
              Text(
                records
                    .map((item) => '${item['model_name']}')
                    .toSet()
                    .join(' · '),
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter(this.records, this.balance, this.days, this.today);
  final List<FinanceRecord> records;
  final double balance;
  final int days;
  final DateTime today;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      0.0,
      balance,
      ...records.map((item) => financeAmount(item['predicted_balance'])),
    ];
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final range = math.max(high - low, 1.0);
    final minValue = low - range * .12;
    final maxValue = high + range * .12;
    const left = 76.0, top = 12.0, bottom = 28.0;
    final width = math.max(size.width - left - 14, 1.0);
    final height = math.max(size.height - top - bottom, 1.0);
    double y(double value) =>
        top + (maxValue - value) / (maxValue - minValue) * height;
    final start = DateTime(today.year, today.month, today.day);
    double x(DateTime date) =>
        left + date.difference(start).inDays / days * width;
    for (final value in {high, 0.0, low}) {
      canvas.drawLine(
        Offset(left, y(value)),
        Offset(left + width, y(value)),
        Paint()
          ..color = AppTheme.borderLight
          ..strokeWidth = 1,
      );
      _text(
        canvas,
        formatVnd(value),
        Offset(0, y(value) - 6),
        AppTheme.textMuted,
        9,
      );
    }
    final first = Offset(left, y(balance));
    canvas.drawCircle(first, 4, Paint()..color = AppTheme.primaryForestGreen);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final item in records) {
      final point = Offset(
        x(financeDate(item['forecast_date'])!),
        y(financeAmount(item['predicted_balance'])),
      );
      path.lineTo(point.dx, point.dy);
      canvas.drawCircle(point, 3, Paint()..color = AppTheme.expenseCoral);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.expenseCoral
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    final end = DateTime(start.year, start.month, start.day + days);
    _text(
      canvas,
      '${start.day}/${start.month}',
      Offset(left - 8, size.height - 18),
      AppTheme.textMuted,
      10,
    );
    _text(
      canvas,
      '${end.day}/${end.month}',
      Offset(left + width - 30, size.height - 18),
      AppTheme.textMuted,
      10,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset point,
    Color color,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, point);
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) =>
      oldDelegate.records != records ||
      oldDelegate.balance != balance ||
      oldDelegate.days != days ||
      oldDelegate.today != today;
}
