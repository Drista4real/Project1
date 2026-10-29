import 'dart:async';
import 'package:project_one/features/settings/services/daily_reminder.dart';
import 'package:project_one/features/settings/services/device_security.dart';

class FakeDeviceSecurity extends DeviceSecurity {
  bool accepted = true;
  Completer<bool>? pending;
  int attempts = 0;
  @override
  bool get supported => true;
  @override
  Future<bool> authenticate() async {
    attempts++;
    return pending == null ? accepted : pending!.future;
  }
}

class FakeDailyReminder extends DailyReminder {
  bool denied = false;
  String? scheduled;
  final permissionRequests = <bool>[];
  @override
  bool get supported => true;
  @override
  Future<void> schedule(String time, {bool requestPermission = true}) async {
    permissionRequests.add(requestPermission);
    if (denied) throw StateError('Quyền thông báo bị từ chối');
    scheduled = time;
  }

  @override
  Future<void> cancel() async => scheduled = null;
}
