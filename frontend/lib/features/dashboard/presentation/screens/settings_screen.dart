import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/kakeibo_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _search = TextEditingController();
  final Set<String> _tags = {};
  String _range = 'Tháng 10';
  bool _reminders = true;
  bool _biometrics = true;
  bool _darkMode = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Tiện Ích và Cài Đặt'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Tìm theo ghi chú, số tiền, #hashtag...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tag in [
                  'dulich',
                  'damcuoi',
                  'quatet',
                  'caphe',
                  'anuong',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterChip(
                      label: Text('# $tag'),
                      selected: _tags.contains(tag),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _tags.add(tag);
                        } else {
                          _tags.remove(tag);
                        }
                      }),
                      showCheckmark: false,
                      backgroundColor: const Color(0xFFEAF0E9),
                      selectedColor: const Color(0xFFD2E5D8),
                      labelStyle: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textCharcoal,
                      ),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDE8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                for (final range in [
                  'Hôm nay',
                  'Tuần này',
                  'Tháng 10',
                  'Tùy chọn',
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _range = range),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _range == range
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              range,
                              style: TextStyle(
                                fontSize: 10,
                                color: _range == range
                                    ? AppTheme.primaryForestGreen
                                    : AppTheme.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (range == 'Tùy chọn')
                              const Icon(Icons.calendar_month, size: 13),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          KakeiboCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _iconTile(
                      Icons.cloud_done_outlined,
                      const Color(0xFFC9EFD9),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Drive...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Đã tự động sao lưu lúc\n10:30 sáng nay • 2.4 MB',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          _notice('Đã bắt đầu sao lưu lên Google Drive.'),
                      icon: const Icon(Icons.sync, size: 15),
                      label: const Text(
                        'Sao lưu ngay',
                        style: TextStyle(fontSize: 10),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEAF1EB),
                        foregroundColor: AppTheme.primaryForestGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F0),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: AppTheme.incomeEmerald,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mã hóa đầu-cuối chuẩn AES-256',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        'An toàn 100%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryForestGreen,
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
              children: [
                Row(
                  children: [
                    _iconTile(Icons.self_improvement, const Color(0xFFFFE0D6)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Ghi chép chánh niệm',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 6),
                              _KakeiboTag(),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '21:00 mỗi tối',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.expenseCoral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _reminders,
                      onChanged: (value) => setState(() => _reminders = value),
                      activeThumbColor: AppTheme.primaryForestGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        size: 18,
                        color: AppTheme.primaryForestGreen,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '“Dành 2 phút mỗi tối để tâm trí an yên và làm chủ dòng tiền.”',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIỆN ÍCH & THIẾT LẬP',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                ),
              ),
              Text(
                'Phiên bản 2.4 Zen',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SettingTile(
            icon: Icons.receipt_long_outlined,
            title: 'Xuất báo cáo Excel / PDF',
            subtitle: 'Hỗ trợ đối soát thuế, chia sẻ gia đình...',
            trailing: const Text(
              'XLSX, PDF  ›',
              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            onTap: () => _notice('Tính năng xuất báo cáo đang được chuẩn bị.'),
          ),
          const SizedBox(height: 9),
          _SettingTile(
            icon: Icons.fingerprint,
            title: 'Bảo mật Face ID & Vân tay',
            subtitle: 'Khóa tức thì khi thoát khỏi ứng dụng',
            trailing: Switch(
              value: _biometrics,
              onChanged: (value) => setState(() => _biometrics = value),
              activeThumbColor: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(height: 9),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Giao diện Tối OLED',
            subtitle: 'Tiết kiệm pin, bảo vệ thị lực ban đêm',
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
              activeThumbColor: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(height: 16),
          KakeiboCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _iconTile(Icons.menu_book, const Color(0xFFEAF1EB), size: 60),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Triết lý Kakeibo 1904',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Mỗi khoản chi là một hạt mầm cho cuộc sống an yên. Xem lại sổ tay để giúp tỉnh thức...',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                          height: 1.3,
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
      bottomNavigationBar: const AppScreenNavigation(selectedIndex: 3),
    );
  }

  Widget _iconTile(IconData icon, Color color, {double size = 42}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: AppTheme.primaryForestGreen, size: size * .52),
  );

  void _notice(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _KakeiboTag extends StatelessWidget {
  const _KakeiboTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE0D6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Text(
      'Kakeibo',
      style: TextStyle(
        fontSize: 9,
        color: AppTheme.expenseCoral,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1EB),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: AppTheme.primaryForestGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
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
            trailing,
          ],
        ),
      ),
    ),
  );
}
