import 'package:flutter/foundation.dart';
import 'package:project_one/features/finance/domain/repositories/management_repository.dart';

/// The signed-in user's public profile fields used across screens.
class UserProfile {
  const UserProfile({
    this.fullName,
    this.email,
    this.avatarUrl,
  });

  final String? fullName;
  final String? email;
  final String? avatarUrl;

  factory UserProfile.fromRecord(Map<String, dynamic> record) {
    String? clean(Object? raw) {
      final value = raw?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return UserProfile(
      fullName: clean(record['full_name']),
      email: clean(record['email']),
      avatarUrl: clean(record['avatar_url']),
    );
  }

  /// Friendly display name with fallback to email prefix.
  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      final prefix = mail.split('@').first.trim();
      if (prefix.isNotEmpty) return prefix;
    }
    return 'Người dùng Kakeibo';
  }

  UserProfile copyWith({
    String? fullName,
    bool clearFullName = false,
    String? email,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) => UserProfile(
    fullName: clearFullName ? null : (fullName ?? this.fullName),
    email: email ?? this.email,
    avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
  );
}

/// Shared profile state so avatar and display name stay in sync app-wide.
class UserProfileNotifier extends ChangeNotifier {
  UserProfileNotifier(this.repository);

  final ManagementRepository repository;

  UserProfile? _profile;
  String? _userId;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  int _generation = 0;

  UserProfile? get profile => _profile;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  String get displayName => _profile?.displayName ?? 'Người dùng Kakeibo';
  String? get avatarUrl => _profile?.avatarUrl;

  /// Sync profile when the active account changes.
  Future<void> syncForUser(String? userId) async {
    if (userId == null) {
      clear();
      return;
    }
    if (userId == _userId && _loaded) return;
    _userId = userId;
    _profile = null;
    _loaded = false;
    await load(force: true);
  }

  /// Clear cached profile on sign-out.
  void clear() {
    _generation++;
    _userId = null;
    _profile = null;
    _loading = false;
    _loaded = false;
    _error = null;
    notifyListeners();
  }

  /// Update cached profile directly from an already-fetched record.
  void setFromRecord(Map<String, dynamic> record) {
    _profile = UserProfile.fromRecord(record);
    _loaded = true;
    _error = null;
    notifyListeners();
  }

  /// Fetch profile from backend `profile/me`.
  Future<void> load({bool force = false}) async {
    if (_loading && !force) return;
    if (_loaded && !force) return;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    try {
      final record = await repository.get('profile', 'me');
      if (generation != _generation) return;
      _profile = UserProfile.fromRecord(record);
      _loaded = true;
    } catch (err) {
      if (generation != _generation) return;
      _error = '$err';
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Persist updated `full_name` and `avatar_url` to backend and notify listeners.
  Future<void> updateProfile({
    required String? fullName,
    required String? avatarUrl,
  }) async {
    final trimmedName = fullName?.trim();
    final trimmedAvatar = avatarUrl?.trim();
    final patch = <String, dynamic>{
      'full_name': (trimmedName == null || trimmedName.isEmpty)
          ? null
          : trimmedName,
      'avatar_url': (trimmedAvatar == null || trimmedAvatar.isEmpty)
          ? null
          : trimmedAvatar,
    };
    await repository.save('profile', patch, key: 'me');
    _profile = (_profile ?? const UserProfile()).copyWith(
      fullName: patch['full_name'] as String?,
      clearFullName: patch['full_name'] == null,
      avatarUrl: patch['avatar_url'] as String?,
      clearAvatarUrl: patch['avatar_url'] == null,
    );
    _loaded = true;
    _error = null;
    notifyListeners();
  }
}
