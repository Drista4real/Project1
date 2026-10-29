import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A single daily reminder, using the device's actual IANA time zone.
class DailyReminder {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void> _tail = Future.value();
  static const notificationId = 1904;

  bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  Future<void> _initialize() async {
    if (_initialized) return;
    if (!supported) {
      throw StateError('Nhắc hằng ngày hỗ trợ Android, iOS và macOS.');
    }
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = _tail.then((_) => operation());
    // The caller receives the error; keep the queue available for later cancellation.
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> schedule(String time, {bool requestPermission = true}) =>
      _enqueue(() => _schedule(time, requestPermission: requestPermission));

  Future<void> _schedule(String time, {required bool requestPermission}) async {
    await _initialize();
    bool? allowed;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()!;
      allowed = requestPermission
          ? await android.requestNotificationsPermission()
          : await android.areNotificationsEnabled();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()!;
      allowed = requestPermission
          ? await ios.requestPermissions(alert: true, sound: true)
          : (await ios.checkPermissions())?.isEnabled;
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()!;
      allowed = requestPermission
          ? await mac.requestPermissions(alert: true, sound: true)
          : (await mac.checkPermissions())?.isEnabled;
    }
    if (allowed != true) {
      await _plugin.cancel(id: notificationId);
      throw StateError(
        'Chưa được cấp quyền thông báo. Hãy bật quyền trong cài đặt thiết bị.',
      );
    }
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    final next = nextOccurrence(time, tz.TZDateTime.now(tz.local));
    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Dành 2 phút cho sổ Kakeibo',
      body: 'Ghi lại thu chi hôm nay để làm chủ dòng tiền.',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_journal',
          'Nhắc ghi chép hằng ngày',
          channelDescription: 'Nhắc dành 2 phút ghi lại thu chi',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Builds the next wall-clock occurrence, preserving daylight-saving changes.
  static tz.TZDateTime nextOccurrence(String time, tz.TZDateTime now) {
    if (!RegExp(r'^\d{2}:\d{2}(:00)?$').hasMatch(time)) {
      throw ArgumentError('Giờ nhắc không hợp lệ.');
    }
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Giờ nhắc không hợp lệ.');
    }
    var next = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + 1,
        hour,
        minute,
      );
    }
    return next;
  }

  Future<void> cancel() => _enqueue(_cancel);

  Future<void> _cancel() async {
    if (!supported) return;
    await _initialize();
    await _plugin.cancel(id: notificationId);
  }
}
