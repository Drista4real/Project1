import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _month = DateTime(2024, 10);
  @override
  Widget build(BuildContext context) {
    const budget = 20000000.0;
    const spent = 13550000.0;
    const categories = [
      (
        'Thiết yếu (Needs)',
        'Seikatsu',
        'Ăn uống, Tiền nhà, Điện nước, Xe',
        7200000.0,
        10000000.0,
        Color(0xFF285B45),
        Icons.home_outlined,
      ),
      (
        'Mong muốn (Wants)',
        'Morau',
        'Mua sắm, Cà phê, Tụ tập bạn bè',
        3800000.0,
        4000000.0,
        Color(0xFFB64F2D),
        Icons.local_cafe_outlined,
      ),
      (
        'Văn hóa (Culture)',
        'Kyoyo',
        'Sách báo, Xem phim, Khóa học',
        1250000.0,
        3000000.0,
        Color(0xFF15936D),
        Icons.menu_book_outlined,
      ),
      (
        'Dự phòng (Extra)',
        'Yobi',
        'Thuốc men, Hiếu hỷ, Sửa đồ gia dụng',
        1300000.0,
        3000000.0,
        Color(0xFF717973),
        Icons.medical_services_outlined,
      ),
    ];
    final remaining = budget - spent;
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Ngân Sách'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              _roundButton(
                Icons.chevron_left,
                () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDE8),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: AppTheme.primaryForestGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tháng ${_month.month}, ${_month.year}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryForestGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _roundButton(
                Icons.chevron_right,
                () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC9EFD9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 7, color: AppTheme.incomeEmerald),
                    SizedBox(width: 4),
                    Text(
                      'Còn 7 ngày',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryForestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          KakeiboCard(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
            child: Column(
              children: [
                SizedBox(
                  height: 230,
                  width: 230,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 208,
                        height: 208,
                        child: CircularProgressIndicator(
                          value: spent / budget,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFFE8EDE8),
                          color: AppTheme.primaryForestGreen,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'KHẢ DỤNG CÒN LẠI',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              letterSpacing: .5,
                            ),
                          ),
                          Text(
                            formatVnd(remaining),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryForestGreen,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9EFD9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Đã dùng 67.8%',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryForestGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _metric('Đã chi tiêu', formatVnd(spent))),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppTheme.borderLight,
                      ),
                      Expanded(
                        child: _metric('Tổng ngân sách', formatVnd(budget)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDE8),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryForestGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Định mức an toàn mỗi ngày',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      Text(
                        '920.000 ₫',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryForestGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '/ 7 ngày tới',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: AppTheme.primaryForestGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '✉  4 Phong Bao Kakeibo',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              Text(
                'Tháng ${_month.month}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final item in categories) _EnvelopeCard(item: item),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Điều chỉnh tỷ lệ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textCharcoal,
                    backgroundColor: const Color(0xFFE8EDE8),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle_outline, size: 17),
                  label: const Text('Tạo phong bao mới'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryForestGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 2),
    );
  }

  Widget _metric(String label, String value) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ],
  );

  Widget _roundButton(IconData icon, VoidCallback onPressed) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EDE8),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 19, color: AppTheme.textCharcoal),
    ),
  );
}

class _EnvelopeCard extends StatelessWidget {
  final (String, String, String, double, double, Color, IconData) item;
  const _EnvelopeCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final (name, jp, description, used, limit, color, icon) = item;
    final progress = used / limit;
    final remaining = limit - used;
    final warning = progress >= .95;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KakeiboCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(35),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name · $jp',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
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
                      formatVnd(used),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: warning
                            ? AppTheme.expenseCoral
                            : AppTheme.textCharcoal,
                      ),
                    ),
                    Text(
                      '/ ${formatVnd(limit)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (warning)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDDDA),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 14,
                      color: AppTheme.expenseCoral,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Gần chạm hạn mức (chỉ còn lại 200.000 ₫)',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.expenseCoral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            KakeiboProgress(
              value: progress,
              color: warning ? AppTheme.expenseCoral : color,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(progress * 100 % 1 == 0 ? 0 : 1)}% đã chi',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: warning ? AppTheme.expenseCoral : color,
                  ),
                ),
                Text(
                  warning ? 'Cần lưu tâm' : 'Còn lại: ${formatVnd(remaining)}',
                  style: TextStyle(
                    fontSize: 9,
                    color: warning ? AppTheme.expenseCoral : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
