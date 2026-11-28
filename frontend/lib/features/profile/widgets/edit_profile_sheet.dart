import 'package:flutter/material.dart';
import 'package:project_one/features/profile/user_profile_notifier.dart';
import 'package:project_one/shared/widgets/user_avatar.dart';

/// Opens a modal bottom sheet to edit the user's display name and avatar.
Future<bool> showEditProfileSheet(
  BuildContext context, {
  required UserProfileNotifier notifier,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _EditProfileSheet(notifier: notifier),
  );
  return saved == true;
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.notifier});

  final UserProfileNotifier notifier;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.notifier.profile?.fullName ?? '',
  );
  late final TextEditingController _urlController = TextEditingController(
    text: isNetworkAvatarUrl(widget.notifier.avatarUrl)
        ? widget.notifier.avatarUrl!
        : '',
  );

  late String? _selectedAvatar = widget.notifier.avatarUrl;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String? get _effectiveAvatarUrl {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) return url;
    return _selectedAvatar;
  }

  Future<void> _save() async {
    if (_saving) return;
    final customUrl = _urlController.text.trim();
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
    try {
      await widget.notifier.updateProfile(
        fullName: _nameController.text,
        avatarUrl: _effectiveAvatarUrl,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Không lưu được hồ sơ: $err';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chỉnh sửa hồ sơ',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  UserAvatar(
                    radius: 36,
                    avatarUrl: _effectiveAvatarUrl,
                    displayName: _nameController.text.trim().isNotEmpty
                        ? _nameController.text.trim()
                        : widget.notifier.displayName,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Xem trước ảnh đại diện',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey('profile-name-field'),
              controller: _nameController,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                hintText: 'Ví dụ: Minh Anh',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Text(
              'Chọn nhanh ảnh đại diện',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PresetTile(
                  selected:
                      _selectedAvatar == null && _urlController.text.trim().isEmpty,
                  label: 'Chữ cái',
                  onTap: _saving
                      ? null
                      : () => setState(() {
                          _selectedAvatar = null;
                          _urlController.clear();
                        }),
                  child: UserAvatar(
                    radius: 18,
                    displayName: _nameController.text.trim().isNotEmpty
                        ? _nameController.text.trim()
                        : widget.notifier.displayName,
                  ),
                ),
                for (final preset in kAvatarPresets)
                  _PresetTile(
                    selected:
                        _selectedAvatar == preset.value &&
                        _urlController.text.trim().isEmpty,
                    label: preset.label,
                    onTap: _saving
                        ? null
                        : () => setState(() {
                            _selectedAvatar = preset.value;
                            _urlController.clear();
                          }),
                    child: UserAvatar(radius: 18, avatarUrl: preset.value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('profile-avatar-url-field'),
              controller: _urlController,
              enabled: !_saving,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Hoặc dán link ảnh (tùy chọn)',
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Xóa link',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _urlController.clear()),
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                key: const ValueKey('profile-save-button'),
                onPressed: _saving ? null : _save,
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
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
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
        width: 70,
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
