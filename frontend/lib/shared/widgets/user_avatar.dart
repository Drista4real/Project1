import 'package:flutter/material.dart';

/// Metadata for a built-in Kakeibo avatar preset stored as `preset:<key>`.
class AvatarPreset {
  const AvatarPreset({
    required this.key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  String get value => 'preset:$key';
}

/// Curated Kakeibo-themed avatar presets stored in `profiles.avatar_url`.
const List<AvatarPreset> kAvatarPresets = [
  AvatarPreset(
    key: 'leaf',
    label: 'Lá xanh',
    icon: Icons.eco_rounded,
    backgroundColor: Color(0xFFD6EFE1),
    foregroundColor: Color(0xFF1B5E3A),
  ),
  AvatarPreset(
    key: 'wallet',
    label: 'Ví tiền',
    icon: Icons.account_balance_wallet_rounded,
    backgroundColor: Color(0xFFE0ECFF),
    foregroundColor: Color(0xFF1D4ED8),
  ),
  AvatarPreset(
    key: 'savings',
    label: 'Tiết kiệm',
    icon: Icons.savings_rounded,
    backgroundColor: Color(0xFFFEF3C7),
    foregroundColor: Color(0xFFB45309),
  ),
  AvatarPreset(
    key: 'coffee',
    label: 'Cà phê',
    icon: Icons.local_cafe_rounded,
    backgroundColor: Color(0xFFF3E8FF),
    foregroundColor: Color(0xFF6D28D9),
  ),
  AvatarPreset(
    key: 'target',
    label: 'Mục tiêu',
    icon: Icons.track_changes_rounded,
    backgroundColor: Color(0xFFFFE4E6),
    foregroundColor: Color(0xFFBE123C),
  ),
  AvatarPreset(
    key: 'star',
    label: 'Ngôi sao',
    icon: Icons.auto_awesome_rounded,
    backgroundColor: Color(0xFFCCFBF1),
    foregroundColor: Color(0xFF0F766E),
  ),
  AvatarPreset(
    key: 'pets',
    label: 'Mèo may mắn',
    icon: Icons.pets_rounded,
    backgroundColor: Color(0xFFFFEDD5),
    foregroundColor: Color(0xFFC2410C),
  ),
  AvatarPreset(
    key: 'book',
    label: 'Sổ Kakeibo',
    icon: Icons.menu_book_rounded,
    backgroundColor: Color(0xFFE2E8F0),
    foregroundColor: Color(0xFF334155),
  ),
];

AvatarPreset? findAvatarPreset(String? avatarUrl) {
  if (avatarUrl == null || !avatarUrl.startsWith('preset:')) return null;
  final key = avatarUrl.substring('preset:'.length);
  for (final preset in kAvatarPresets) {
    if (preset.key == key) return preset;
  }
  return null;
}

bool isNetworkAvatarUrl(String? avatarUrl) {
  if (avatarUrl == null) return false;
  final trimmed = avatarUrl.trim().toLowerCase();
  return trimmed.startsWith('https://') || trimmed.startsWith('http://');
}

/// Extract 1-2 uppercase initials from a display name.
String avatarInitials(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  final first = parts.first.characters.first;
  final last = parts.last.characters.first;
  return '$first$last'.toUpperCase();
}

/// Circular avatar supporting network URL, `preset:<key>`, or name initials.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.displayName,
    this.radius = 20,
  });

  final String? avatarUrl;
  final String? displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    if (isNetworkAvatarUrl(avatarUrl)) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.network(
            avatarUrl!.trim(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _FallbackAvatar(displayName: displayName, radius: radius),
          ),
        ),
      );
    }

    final preset = findAvatarPreset(avatarUrl);
    if (preset != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: preset.backgroundColor,
        child: Icon(
          preset.icon,
          color: preset.foregroundColor,
          size: radius * 1.1,
        ),
      );
    }

    return _FallbackAvatar(displayName: displayName, radius: radius);
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({this.displayName, required this.radius});

  final String? displayName;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = avatarInitials(displayName);
    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.82,
              ),
            )
          : Icon(Icons.person, color: colors.primary, size: radius * 1.15),
    );
  }
}
