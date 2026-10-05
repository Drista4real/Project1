import 'package:flutter/material.dart';

import 'package:project_one/core/theme/app_theme.dart';
import 'package:project_one/core/config/supabase_config.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/finance/domain/usecases/finance_insights.dart';
import 'package:project_one/features/transactions/screens/transaction_detail_screen.dart';
import 'package:project_one/features/auth/screens/auth_screen.dart';
import 'package:project_one/features/management/screens/management_screen.dart';
import 'package:project_one/features/management/open_finance_module.dart';
import 'package:project_one/app/widgets/app_screen_header.dart';
import 'package:project_one/app/widgets/app_screen_navigation.dart';
import 'package:project_one/shared/widgets/kakeibo_card.dart';
import 'package:project_one/shared/formatters/currency_formatter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.repository});
  final ManagementRepository? repository;

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
  bool _loading = false;
  bool _saving = false;
  String? _error;
  int _generation = 0;
  FinanceRecord? _profile;
  List<FinanceRecord> _tagRecords = [];
  List<FinanceRecord> _transactions = [];
  List<FinanceRecord> _transactionTags = [];
  DateTimeRange? _customRange;
  ManagementRepository get _repository =>
      widget.repository ?? AppDependencies.managementRepository;

  Future<void> _manage(String resource) async {
    await openFinanceModule(context, resource, repository: _repository);
    if (mounted) await _loadSettings();
  }

  @override
  void initState() {
    super.initState();
    _range = 'Tháng này';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        _repository.get('profile', 'me'),
        _repository.references('tags'),
        _repository.references('transactions'),
        _repository.references('transaction_tags'),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _profile = values[0] as FinanceRecord;
        _tagRecords = values[1] as List<FinanceRecord>;
        _transactions = values[2] as List<FinanceRecord>;
        _transactionTags = values[3] as List<FinanceRecord>;
        _reminders = _profile!['reminder_time'] != null;
        _biometrics = _profile!['biometrics_enabled'] == true;
        _darkMode = _profile!['dark_mode_enabled'] == true;
        _tags.removeWhere(
          (name) => !_tagRecords.any((tag) => tag['name'] == name),
        );
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = '$error';
          _profile = null;
          _transactions = [];
          _tagRecords = [];
          _transactionTags = [];
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _savePreference(String field, dynamic value) async {
    if (_saving || _profile == null) return;
    setState(() => _saving = true);
    try {
      await _repository.save('profile', {field: value}, key: 'me');
      if (mounted) await _loadSettings();
    } catch (error) {
      if (mounted) _notice('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectRange(String range) async {
    if (range == 'Tùy chọn') {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200),
        initialDateRange: _customRange,
      );
      if (selected == null || !mounted) return;
      setState(() {
        _customRange = selected;
        _range = range;
      });
    } else {
      setState(() => _range = range);
    }
  }

  List<FinanceRecord> get _filteredTransactions {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (_range) {
      'Hôm nay' => today,
      'Tuần này' => DateTime(now.year, now.month, now.day - now.weekday + 1),
      'Tùy chọn' => _customRange?.start ?? today,
      _ => DateTime(now.year, now.month),
    };
    final end = switch (_range) {
      'Hôm nay' => DateTime(now.year, now.month, now.day + 1),
      'Tuần này' => DateTime(now.year, now.month, now.day - now.weekday + 8),
      'Tùy chọn' =>
        _customRange == null
            ? DateTime(now.year, now.month, now.day + 1)
            : DateTime(
                _customRange!.end.year,
                _customRange!.end.month,
                _customRange!.end.day + 1,
              ),
      _ => DateTime(now.year, now.month + 1),
    };
    final query = _search.text.trim().toLowerCase();
    final tagIds = _tagRecords
        .where((tag) => _tags.contains(tag['name']))
        .map((tag) => tag['id'])
        .toSet();
    final taggedIds = _transactionTags
        .where((item) => tagIds.contains(item['tag_id']))
        .map((item) => item['transaction_id'])
        .toSet();
    return _transactions.where((item) {
      final date = financeDate(item['transaction_date']);
      if (date == null || date.isBefore(start) || !date.isBefore(end)) {
        return false;
      }
      if (_tags.isNotEmpty && !taggedIds.contains(item['id'])) return false;
      final category = item['categories'];
      final relatedNames = _transactionTags
          .where((link) => link['transaction_id'] == item['id'])
          .map(
            (link) => _tagRecords
                .where((tag) => tag['id'] == link['tag_id'])
                .map((tag) => tag['name'])
                .join(' '),
          )
          .join(' ');
      final text =
          '${item['clean_description'] ?? ''} ${item['raw_description'] ?? ''} ${item['amount']} ${category is Map ? category['name'] : ''} $relatedNames'
              .toLowerCase();
      return query.isEmpty || text.contains(query.replaceFirst('#', ''));
    }).toList();
  }

  String _dateLabel(FinanceRecord item) {
    final date = financeDate(item['transaction_date']);
    return date == null ? '' : '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _filteredTransactions;
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Tiện Ích và Cài Đặt'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.person_outline,
                color: AppTheme.primaryForestGreen,
              ),
              title: Text(
                SupabaseConfig.currentUser?.email ??
                    'Đăng nhập để quản lý giao dịch',
              ),
              trailing: TextButton(
                onPressed: () async {
                  if (SupabaseConfig.isAuthenticated) {
                    await SupabaseConfig.client.auth.signOut();
                  } else {
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  }
                  if (mounted) await _loadSettings();
                },
                child: Text(
                  SupabaseConfig.isAuthenticated ? 'Đăng xuất' : 'Đăng nhập',
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!),
                    TextButton(
                      onPressed: _loading ? null : _loadSettings,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          if (_profile != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${_profile!['full_name'] ?? 'Hồ sơ cá nhân'}'),
                subtitle: Text(
                  'Ngày nhận lương: ${_profile!['payroll_day'] ?? 'Chưa đặt'}',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  await openFinanceModule(
                    context,
                    'profile',
                    repository: _repository,
                  );
                  if (mounted) await _loadSettings();
                },
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.primaryForestGreen,
              ),
              title: const Text('Tất cả dữ liệu tài chính'),
              subtitle: const Text('Các nhóm dữ liệu và lịch sử tư vấn'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManagementScreen(repository: _repository),
                  ),
                );
                if (mounted) await _loadSettings();
              },
            ),
          ),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
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
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.category_outlined,
                color: AppTheme.primaryForestGreen,
              ),
              title: const Text('Danh mục thu / chi'),
              subtitle: const Text('Tùy chỉnh cách phân loại giao dịch'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _manage('categories'),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thẻ của bạn',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => _manage('tags'),
                child: const Text('Quản lý thẻ'),
              ),
              TextButton(
                onPressed: () => _manage('transaction_tags'),
                child: const Text('Gắn thẻ'),
              ),
            ],
          ),
          if (!_loading && _profile != null && _tagRecords.isEmpty)
            const Text(
              'Chưa có thẻ. Tạo thẻ và gắn vào giao dịch để lọc theo sự kiện.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final tag in _tagRecords.map((item) => '${item['name']}'))
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
                  'Tháng này',
                  'Tùy chọn',
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _selectRange(range),
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
          if (_customRange != null && _range == 'Tùy chọn')
            Text(
              '${_customRange!.start.day}/${_customRange!.start.month}/${_customRange!.start.year} – ${_customRange!.end.day}/${_customRange!.end.month}/${_customRange!.end.year}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          if (_profile != null)
            KakeiboCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giao dịch phù hợp (${matches.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (matches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Không có giao dịch phù hợp.'),
                    ),
                  for (final item in matches.take(12))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item['clean_description'] ?? item['raw_description'] ?? 'Giao dịch'}',
                      ),
                      subtitle: Text(_dateLabel(item)),
                      trailing: Text(formatVnd(financeAmount(item['amount']))),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(
                              transactionId: item['id'] as int,
                            ),
                          ),
                        );
                        if (mounted) await _loadSettings();
                      },
                    ),
                  if (matches.length > 12)
                    const Text(
                      'Hiển thị 12 kết quả đầu tiên. Thu hẹp bộ lọc để tìm thêm.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dữ liệu tài chính',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _profile == null
                                ? 'Chưa tải dữ liệu'
                                : '${_transactions.length} giao dịch · ${_tagRecords.length} thẻ',
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
                      onPressed: _loading || _saving ? null : _loadSettings,
                      icon: const Icon(Icons.sync, size: 15),
                      label: const Text(
                        'Tải lại',
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
                          'Dữ liệu riêng theo tài khoản đăng nhập',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        'Cá nhân',
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
                    Expanded(
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
                            _profile?['reminder_time'] == null
                                ? 'Chưa đặt giờ nhắc'
                                : '${_profile!['reminder_time']}'.substring(
                                    0,
                                    5,
                                  ),
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
                      onChanged: _loading || _saving || _profile == null
                          ? null
                          : (value) => _savePreference(
                              'reminder_time',
                              value ? '20:30:00' : null,
                            ),
                      activeThumbColor: AppTheme.primaryForestGreen,
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _loading || _saving || _profile == null
                      ? null
                      : () async {
                          final stored =
                              '${_profile?['reminder_time'] ?? '20:30:00'}'
                                  .split(':');
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: (int.tryParse(stored[0]) ?? 20).clamp(
                                0,
                                23,
                              ),
                              minute: (int.tryParse(stored[1]) ?? 30).clamp(
                                0,
                                59,
                              ),
                            ),
                          );
                          if (picked != null && mounted) {
                            await _savePreference(
                              'reminder_time',
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00',
                            );
                          }
                        },
                  icon: const Icon(Icons.schedule),
                  label: const Text('Chọn giờ nhắc'),
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
            title: 'Ưu tiên Face ID & Vân tay',
            subtitle: 'Lưu tùy chọn; khóa sinh trắc học chưa được bật',
            trailing: Switch(
              value: _biometrics,
              onChanged: _loading || _saving || _profile == null
                  ? null
                  : (value) => _savePreference('biometrics_enabled', value),
              activeThumbColor: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(height: 9),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Ưu tiên giao diện tối',
            subtitle: 'Lưu lựa chọn vào hồ sơ cá nhân',
            trailing: Switch(
              value: _darkMode,
              onChanged: _loading || _saving || _profile == null
                  ? null
                  : (value) => _savePreference('dark_mode_enabled', value),
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
      bottomNavigationBar: AppScreenNavigation(
        selectedIndex: 3,
        onTransactionAdded: _loadSettings,
      ),
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
