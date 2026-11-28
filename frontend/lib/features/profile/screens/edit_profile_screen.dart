import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_one/app/app_dependencies.dart';
import 'package:project_one/app/widgets/app_exit_button.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';
import 'package:project_one/features/profile/user_profile_notifier.dart';
import 'package:project_one/shared/widgets/kakeibo_card.dart';
import 'package:project_one/shared/widgets/user_avatar.dart';

/// Dedicated, clean profile editor replacing the generic CRUD form.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.repository,
    this.initialProfile,
    this.profileNotifier,
  });

  final ManagementRepository repository;
  final Map<String, dynamic>? initialProfile;
  final UserProfileNotifier? profileNotifier;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _payrollController = TextEditingController();
  final _savingsController = TextEditingController();
  final _avatarUrlController = TextEditingController();

  String? _selectedPresetOrNull;
  String _currency = 'VND';
  bool _loading = false;
  bool _saving = false;
  String? _error;
  bool _showUrlField = false;

  static const _currencies = ['VND', 'USD', 'JPY', 'EUR'];

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _applyRecord(widget.initialProfile!);
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _payrollController.dispose();
    _savingsController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _applyRecord(Map<String, dynamic> record) {
    _nameController.text = record['full_name']?.toString() ?? '';
    _payrollController.text = (record['payroll_day'] ?? 5).toString();
    final rawSavings = record['monthly_savings_target'];
    final parsedSavings = num.tryParse('${rawSavings ?? 0}') ?? 0;
    _savingsController.text = parsedSavings == parsedSavings.roundToDouble()
        ? parsedSavings.toInt().toString()
        : parsedSavings.toString();

    final avatar = record['avatar_url']?.toString().trim();
    if (isNetworkAvatarUrl(avatar)) {
      _avatarUrlController.text = avatar!;
      _selectedPresetOrNull = null;
      _showUrlField = true;
    } else {
      _avatarUrlController.clear();
      _selectedPresetOrNull = (avatar != null && avatar.isNotEmpty)
          ? avatar
          : null;
      _showUrlField = false;
    }

    final curr = record['currency']?.toString().toUpperCase() ?? 'VND';
    _currency = _currencies.contains(curr) ? curr : 'VND';
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final record = await widget.repository.get('profile', 'me');
      if (!mounted) return;
      setState(() {
        _applyRecord(record);
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được hồ sơ: $err';
      });
    }
  }

  String? get _effectiveAvatarUrl {
    final customUrl = _avatarUrlController.text.trim();
    if (customUrl.isNotEmpty) return customUrl;
    return _selectedPresetOrNull;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final customUrl = _avatarUrlController.text.trim();
    if (customUrl.isNotEmpty && !isNetworkAvatarUrl(customUrl)) {
      setState(() {
        _error = 'Link ảnh cần bắt đầu bằng http:// hoặc https://';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final trimmedName = _nameController.text.trim();
    final payrollDay = int.tryParse(_payrollController.text.trim()) ?? 5;
    final savingsText = _savingsController.text.trim().replaceAll(',', '.');
    final savingsTarget = num.tryParse(savingsText) ?? 0;

    final patch = <String, dynamic>{
      'full_name': trimmedName.isEmpty ? null : trimmedName,
      'avatar_url': _effectiveAvatarUrl,
      'payroll_day': payrollDay,
      'monthly_savings_target': savingsTarget,
      'currency': _currency,
    };

    try {
      await widget.repository.save('profile', patch, key: 'me');
      final notifier = widget.profileNotifier ?? AppDependencies.userProfile;
      notifier.setFromRecord({
        ...?widget.initialProfile,
        ...patch,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không lưu được thay đổi: $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final previewName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (widget.initialProfile?['email']?.toString() ?? 'Hồ sơ cá nhân');

    return Scaffold(
      appBar: AppBar(
        leading: AppExitButton(close: true, enabled: !_saving),
        title: const Text('Hồ sơ cá nhân'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  KakeiboCard(
                    child: Column(
                      children: [
                        UserAvatar(
                          radius: 40,
                          avatarUrl: _effectiveAvatarUrl,
                          displayName: previewName,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          previewName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ảnh đại diện',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.start,
                          children: [
                            _AvatarChoice(
                              selected:
                                  _selectedPresetOrNull == null &&
                                  _avatarUrlController.text.trim().isEmpty,
                              label: 'Chữ cái',
                              onTap: _saving
                                  ? null
                                  : () => setState(() {
                                      _selectedPresetOrNull = null;
                                      _avatarUrlController.clear();
                                    }),
                              child: UserAvatar(
                                radius: 18,
                                displayName: previewName,
                              ),
                            ),
                            for (final preset in kAvatarPresets)
                              _AvatarChoice(
                                selected:
                                    _selectedPresetOrNull == preset.value &&
                                    _avatarUrlController.text.trim().isEmpty,
                                label: preset.label,
                                onTap: _saving
                                    ? null
                                    : () => setState(() {
                                        _selectedPresetOrNull = preset.value;
                                        _avatarUrlController.clear();
                                      }),
                                child: UserAvatar(
                                  radius: 18,
                                  avatarUrl: preset.value,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(
                                    () => _showUrlField = !_showUrlField,
                                  ),
                            icon: Icon(
                              _showUrlField
                                  ? Icons.expand_less
                                  : Icons.link_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _showUrlField
                                  ? 'Ẩn link ảnh tùy chỉnh'
                                  : 'Dùng link ảnh riêng (URL)',
                            ),
                          ),
                        ),
                        if (_showUrlField) ...[
                          const SizedBox(height: 6),
                          TextFormField(
                            key: const ValueKey('profile-avatar-url-field'),
                            controller: _avatarUrlController,
                            enabled: !_saving,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              labelText: 'Đường dẫn ảnh',
                              hintText: 'https://...',
                              prefixIcon: const Icon(Icons.link_rounded),
                              suffixIcon: _avatarUrlController.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Xóa link',
                                      onPressed: _saving
                                          ? null
                                          : () => setState(
                                              () => _avatarUrlController.clear(),
                                            ),
                                      icon: const Icon(Icons.close),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() => _error = null),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  KakeiboCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thông tin hiển thị',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('profile-name-field'),
                          controller: _nameController,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            hintText: 'Ví dụ: Minh Anh',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  KakeiboCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thu nhập & Tiết kiệm',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('profile-payroll-field'),
                          controller: _payrollController,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Ngày nhận lương hàng tháng',
                            hintText: '1 - 31',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          validator: (value) {
                            final day = int.tryParse(value?.trim() ?? '');
                            if (day == null || day < 1 || day > 31) {
                              return 'Nhập ngày từ 1 đến 31';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const ValueKey('profile-savings-field'),
                          controller: _savingsController,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Mục tiêu tiết kiệm mỗi tháng',
                            hintText: 'Ví dụ: 500000',
                            prefixIcon: Icon(Icons.savings_outlined),
                            suffixText: 'đ',
                          ),
                          validator: (value) {
                            final raw = (value ?? '').trim().replaceAll(',', '.');
                            final numVal = num.tryParse(raw);
                            if (numVal == null || numVal < 0) {
                              return 'Nhập số tiền không âm';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration: const InputDecoration(
                            labelText: 'Tiền tệ mặc định',
                            prefixIcon: Icon(Icons.payments_outlined),
                          ),
                          items: _currencies
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() => _currency = val);
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  ],
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              key: const ValueKey('profile-save-button'),
              onPressed: (_loading || _saving) ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Lưu thay đổi'),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.selected,
    required this.label,
    required this.child,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.45) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
