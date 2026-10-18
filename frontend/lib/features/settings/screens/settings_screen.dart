import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_one/features/settings/cubit/settings_cubit.dart';
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
import 'package:project_one/features/settings/cubit/app_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.repository, this.preferences});
  final ManagementRepository? repository;
  final AppPreferences? preferences;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _search = TextEditingController();
  late final _cubit = SettingsCubit(_repository)..refresh();
  Set<String> get _tags => _cubit.state.tags;
  String get _range => _cubit.state.range;
  AppPreferences get _preferences =>
      widget.preferences ?? AppDependencies.preferences;
  String? get _reminderTime => _profile?['reminder_time'] as String?;
  Future<void> _saveReminder(String? value) =>
      _saveLegacyPreference('reminder_time', value);
  Future<void> _saveBiometrics(bool value) => _preferences.setBiometrics(value);
  Future<void> _saveLegacyPreference(String field, dynamic value) =>
      _cubit.savePreference(field, value);
  bool _updatingDevice = false;
  bool get _reminders => _reminderTime != null;
  bool get _biometrics => _preferences.biometrics;
  bool get _darkMode => _preferences.darkMode;
  bool get _loading => _cubit.state.loading;
  bool get _saving => _cubit.state.saving || _updatingDevice;
  String? get _error => _cubit.state.error;
  FinanceRecord? get _profile => _cubit.state.data?.profile;
  List<FinanceRecord> get _tagRecords => _cubit.state.data?.tags ?? [];
  List<FinanceRecord> get _transactions =>
      _cubit.state.data?.transactions ?? [];
  DateTimeRange? get _customRange => _cubit.state.customRange;
  ManagementRepository get _repository =>
      widget.repository ?? AppDependencies.managementRepository;

  Future<void> _manage(String resource) async {
    await openFinanceModule(context, resource, repository: _repository);
    if (mounted) await _loadSettings();
  }

  Future<void> _loadSettings() => _cubit.refresh();

  Future<void> _updateDevice(Future<void> Function() update) async {
    if (_saving) return;
    setState(() => _updatingDevice = true);
    try {
      await update();
    } catch (error) {
      if (mounted) _notice('$error');
    } finally {
      if (mounted) setState(() => _updatingDevice = false);
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
      _cubit.selectRange(range, customRange: selected);
    } else {
      _cubit.selectRange(range);
    }
  }

  List<FinanceRecord> get _filteredTransactions =>
      _cubit.state.filteredTransactions(DateTime.now());

  String _dateLabel(FinanceRecord item) {
    final date = financeDate(item['transaction_date']);
    return date == null ? '' : '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _search.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) => BlocBuilder<SettingsCubit, SettingsState>(
      bloc: _cubit,
      builder: (context, state) => _buildContent(context),
    ),
  );

  Widget _buildContent(BuildContext context) {
    final matches = _filteredTransactions;
    return Scaffold(
      appBar: const AppScreenHeader(subtitle: 'Tiện Ích và Cài Đặt'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.primary,
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
          if (_preferences.error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_preferences.error!),
              ),
            ),
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
              leading: Icon(
                Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Tất cả dữ liệu tài chính'),
              subtitle: const Text(
                'Quản lý thu chi · Xem lịch sử dự báo và tư vấn',
              ),
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
            onChanged: _cubit.search,
            decoration: InputDecoration(
              hintText: 'Tìm theo ghi chú, số tiền, #hashtag...',
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
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
              leading: Icon(
                Icons.category_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Danh mục thu / chi'),
              subtitle: const Text('Tùy chỉnh cách phân loại giao dịch'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _manage('categories'),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text(
                'Thẻ của bạn',
                style: TextStyle(fontWeight: FontWeight.w600),
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
            Text(
              'Chưa có thẻ. Tạo thẻ và gắn vào giao dịch để lọc theo sự kiện.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                      onSelected: (selected) => _cubit.selectTag(tag, selected),
                      showCheckmark: false,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              ? Theme.of(context).colorScheme.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                range,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _range == range
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
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
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                    Text(
                      'Hiển thị 12 kết quả đầu tiên. Thu hẹp bộ lọc để tìm thêm.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        'Cá nhân',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Ghi chép chánh niệm',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              _KakeiboTag(),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            !_preferences.reminders.supported
                                ? 'Nhắc hằng ngày hỗ trợ Android, iOS và macOS'
                                : _reminderTime == null
                                ? 'Chưa đặt giờ nhắc'
                                : _reminderTime!.substring(0, 5),
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
                      onChanged:
                          _loading ||
                              _saving ||
                              _profile == null ||
                              !_preferences.reminders.supported
                          ? null
                          : (value) => _updateDevice(
                              () => _saveReminder(value ? '20:30:00' : null),
                            ),
                      activeThumbColor: AppTheme.primaryForestGreen,
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed:
                      _loading ||
                          _saving ||
                          _profile == null ||
                          !_preferences.reminders.supported
                      ? null
                      : () async {
                          final stored = (_reminderTime ?? '20:30:00').split(
                            ':',
                          );
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
                            await _updateDevice(
                              () => _saveReminder(
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00',
                              ),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '“Dành 2 phút mỗi tối để tâm trí an yên và làm chủ dòng tiền.”',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'TIỆN ÍCH & THIẾT LẬP',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
              ),
              Text(
                'Kakeibo Zen',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SettingTile(
            icon: Icons.receipt_long_outlined,
            title: 'Xuất báo cáo Excel / PDF',
            subtitle: 'Hỗ trợ đối soát thuế, chia sẻ gia đình...',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _notice('Tính năng xuất báo cáo đang được chuẩn bị.'),
          ),
          const SizedBox(height: 9),
          _SettingTile(
            icon: Icons.fingerprint,
            title: 'Khóa bằng Face ID & Vân tay',
            subtitle: _preferences.security.supported
                ? 'Xác thực khi mở app · Có thể dùng mã khóa thiết bị'
                : 'Thiết bị này chưa hỗ trợ khóa ứng dụng',
            trailing: Switch(
              value: _biometrics,
              onChanged:
                  _loading ||
                      _saving ||
                      _profile == null ||
                      !_preferences.security.supported
                  ? null
                  : (value) => _updateDevice(() => _saveBiometrics(value)),
              activeThumbColor: AppTheme.primaryForestGreen,
            ),
          ),
          const SizedBox(height: 9),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'Giao diện tối',
            subtitle: 'Áp dụng toàn ứng dụng trên thiết bị này',
            trailing: Switch(
              value: _darkMode,
              onChanged: _loading || _saving || _profile == null
                  ? null
                  : (value) =>
                        _updateDevice(() => _preferences.setDarkMode(value)),
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
                Expanded(
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.primaryContainer
          : color,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(
      icon,
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.onPrimaryContainer
          : AppTheme.primaryForestGreen,
      size: size * .52,
    ),
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
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
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
