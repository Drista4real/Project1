import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_one/features/settings/services/daily_reminder.dart';
import 'package:project_one/features/settings/services/device_security.dart';

/// Device-specific opt-ins are scoped to the signed-in account.
class AppPreferences extends ChangeNotifier {
  AppPreferences({DeviceSecurity? security, DailyReminder? reminders})
    : security = security ?? DeviceSecurity(),
      reminders = reminders ?? DailyReminder();

  final DeviceSecurity security;
  final DailyReminder reminders;
  SharedPreferences? _store;
  String? _userId;
  bool _dark = false;
  bool _biometrics = false;
  bool _locked = false;
  bool _authenticating = false;
  String? _reminderTime;
  String? _error;
  int _generation = 0;

  ThemeMode get themeMode => _dark ? ThemeMode.dark : ThemeMode.light;
  String? get userId => _userId;
  bool get darkMode => _dark;
  bool get biometrics => _biometrics;
  bool get locked => _locked;
  bool get authenticating => _authenticating;
  String? get reminderTime => _reminderTime;
  String? get error => _error;
  String get _prefix => 'settings.${_userId ?? 'guest'}.';

  Future<void> loadUser(String? userId) async {
    if (_store != null && userId == _userId) return;
    final generation = ++_generation;
    _userId = userId;
    // Cover the previous account immediately, before reading disk or plugins.
    _locked = true;
    _authenticating = false;
    _error = null;
    notifyListeners();
    _store ??= await SharedPreferences.getInstance();
    if (generation != _generation) return;
    _dark = _store!.getBool('${_prefix}dark') ?? false;
    _biometrics =
        userId != null && (_store!.getBool('${_prefix}biometrics') ?? false);
    _reminderTime = userId == null
        ? null
        : _store!.getString('${_prefix}reminder');
    _locked = _biometrics;
    notifyListeners();
    try {
      if (_reminderTime != null) {
        await reminders.schedule(_reminderTime!, requestPermission: false);
      } else {
        await reminders.cancel();
      }
    } catch (error) {
      if (generation == _generation) {
        _reminderTime = null;
        _error = 'Không thể khôi phục lịch nhắc: $error';
        notifyListeners();
      }
    }
  }

  Future<void> setDarkMode(bool value) async {
    final generation = _generation;
    final prefix = _prefix;
    _store ??= await SharedPreferences.getInstance();
    if (!await _store!.setBool('${prefix}dark', value)) {
      throw StateError('Không thể lưu giao diện trên thiết bị.');
    }
    if (generation != _generation) return;
    _dark = value;
    notifyListeners();
  }

  Future<void> setBiometrics(bool value) async {
    final generation = _generation;
    // Both enabling and disabling a lock require the device owner's presence.
    _authenticating = true;
    notifyListeners();
    bool accepted;
    try {
      accepted = await security.authenticate();
    } finally {
      if (generation == _generation) {
        _authenticating = false;
        notifyListeners();
      }
    }
    if (!accepted) throw StateError('Xác thực đã bị hủy.');
    if (generation != _generation) return;
    _store ??= await SharedPreferences.getInstance();
    if (!await _store!.setBool('${_prefix}biometrics', value)) {
      throw StateError('Không thể lưu khóa ứng dụng.');
    }
    _biometrics = value;
    _locked = false;
    notifyListeners();
  }

  Future<void> setReminder(String? time) async {
    final generation = _generation;
    final prefix = _prefix;
    if (time == null) {
      await reminders.cancel();
    } else {
      await reminders.schedule(time);
    }
    if (generation != _generation) return;
    _store ??= await SharedPreferences.getInstance();
    final saved = time == null
        ? await _store!.remove('${prefix}reminder')
        : await _store!.setString('${prefix}reminder', time);
    if (generation != _generation) return;
    if (!saved) {
      // Do not leave an untracked notification scheduled after a storage error.
      await reminders.cancel();
      _reminderTime = null;
      notifyListeners();
      throw StateError('Không thể lưu lịch nhắc trên thiết bị.');
    }
    _reminderTime = time;
    _error = null;
    notifyListeners();
  }

  void lock() {
    if (!_biometrics || _authenticating) return;
    _locked = true;
    notifyListeners();
  }

  /// Signing out removes access; a later sign-in can enroll this device again.
  Future<void> clearLockAfterSignOut(String previousUserId) async {
    if (_userId != null) {
      throw StateError('Cần đăng xuất trước khi đặt lại khóa.');
    }
    _store ??= await SharedPreferences.getInstance();
    if (!await _store!.remove('settings.$previousUserId.biometrics')) {
      throw StateError('Không thể đặt lại khóa trên thiết bị.');
    }
  }

  Future<void> unlock() async {
    if (!_locked || _authenticating) return;
    final generation = _generation;
    _authenticating = true;
    _error = null;
    notifyListeners();
    try {
      final accepted = await security.authenticate();
      if (generation != _generation) return;
      _locked = !accepted;
      if (!accepted) _error = 'Chưa xác thực. Nhấn Mở khóa để thử lại.';
    } catch (error) {
      if (generation == _generation) _error = 'Không thể mở khóa: $error';
    } finally {
      if (generation == _generation) {
        _authenticating = false;
        notifyListeners();
      }
    }
  }
}
