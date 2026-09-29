import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../finance/domain/entities/financial_overview.dart';
import '../widgets/kakeibo_ui.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _getOverview = AppDependencies.getOverview;
  FinancialOverview _overview = FinancialOverview(
    currentBalance: 18450000,
    monthlyIncome: 24500000,
    monthlyExpense: 13550000,
  );
  String _period = 'Tháng';

  @override
  void initState() {
    super.initState();
    _getOverview()
        .then((value) {
          if (mounted) setState(() => _overview = value);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFA64220),
      Color(0xFF285B45),
      Color(0xFFF17A59),
      Color(0xFF76CBB2),
      Color(0xFFC4CDC7),
    ];
    const names = ['Ăn uống', 'Nhà ở', 'Mua sắm', 'Di chuyển', 'Khác'];
    const shares = [42, 28, 15, 10, 5];
    const amounts = [5690000, 3790000, 2030000, 1355000, 685000];
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Báo Cáo'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDE8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                for (final label in ['Tuần', 'Tháng', 'Năm'])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _period = label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _period == label
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _period == label
                                ? AppTheme.primaryForestGreen
                                : AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BÁO CÁO TÀI CHÍNH',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                      letterSpacing: .6,
                    ),
                  ),
                  Text(
                    _period == 'Tháng'
                        ? 'Tháng ${DateTime.now().month}, ${DateTime.now().year}'
                        : '$_period ${DateTime.now().year}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryForestGreen,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.spa_outlined,
                      size: 15,
                      color: AppTheme.primaryForestGreen,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'An yên',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryForestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          KakeiboCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.donut_large,
                      size: 19,
                      color: AppTheme.primaryForestGreen,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Phân bổ chi tiêu',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.info_outline, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                            'Tổng chi tháng ${DateTime.now().month}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Text(
                            formatVnd(_overview.monthlyExpense),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryForestGreen,
                            ),
                          ),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_outlined,
                                size: 13,
                                color: AppTheme.incomeEmerald,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '92% định mức',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                          '${names[i]} (${shares[i]}%)',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          KakeiboCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xu hướng trong tuần',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Text(
                  'Mức chi tiêu bình quân ngày theo tuần gần nhất',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 112,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      const values = [.42, .53, .34, .66, .82, .98, 1.0];
                      final weekend = i > 4;
                      return Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (weekend)
                              Text(
                                i == 5 ? '1.15m' : '1.28m',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.expenseCoral,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              height: 80 * values[i],
                              width: 28,
                              decoration: BoxDecoration(
                                color: weekend
                                    ? (i == 5
                                          ? const Color(0xFFB95330)
                                          : const Color(0xFFA64220))
                                    : const Color(0xFFE4E9E4),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i],
                              style: TextStyle(
                                fontSize: 10,
                                color: weekend
                                    ? AppTheme.expenseCoral
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('💡'),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuối tuần chi tiêu cao hơn 35% so với ngày trong tuần.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Bạn có thể tự chuẩn bị bữa tối tại nhà vào Thứ Bảy để duy trì dòng tiền thanh thản.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
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
          ),
          const SizedBox(height: 16),
          KakeiboCard(
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
                const SizedBox(height: 12),
                for (var i = 0; i < names.length; i++)
                  _CategoryReportRow(
                    name: names[i],
                    amount: amounts[i],
                    share: shares[i],
                    color: colors[i],
                    icon: [
                      Icons.restaurant,
                      Icons.home_outlined,
                      Icons.shopping_bag_outlined,
                      Icons.local_gas_station_outlined,
                      Icons.movie_outlined,
                    ][i],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.spa, color: AppTheme.primaryForestGreen),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tâm niệm Kakeibo\nBiết rõ dòng tiền là bước đầu tiên để tâm trí luôn an định giữa nhịp sống bận rộn.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 1),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<int> shares;
  final List<Color> colors;
  _DonutPainter({required this.shares, required this.colors});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -1.5708;
    for (var i = 0; i < shares.length; i++) {
      final sweep = 6.28318 * shares[i] / 100;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect.deflate(10), start, sweep - .035, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.shares != shares || oldDelegate.colors != colors;
}

class _CategoryReportRow extends StatelessWidget {
  final String name;
  final num amount;
  final int share;
  final Color color;
  final IconData icon;
  const _CategoryReportRow({
    required this.name,
    required this.amount,
    required this.share,
    required this.color,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withAlpha(35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      'Cần thiết & Gặp gỡ',
                      'Cố định hàng tháng',
                      'Ngẫu hứng & Sở thích',
                      'Đi lại công việc',
                      'Sách, phim & thư giãn',
                    ][[
                      'Ăn uống',
                      'Nhà ở',
                      'Mua sắm',
                      'Di chuyển',
                      'Khác',
                    ].indexOf(name)],
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatVnd(amount),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textCharcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        KakeiboProgress(value: share / 50, color: color),
      ],
    ),
  );
}
