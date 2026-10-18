import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_one/features/settings/cubit/app_preferences.dart';
import 'package:project_one/features/settings/widgets/app_lock_gate.dart';
import '../../helpers/device_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeDeviceSecurity security;
  late FakeDailyReminder reminders;
  late AppPreferences preferences;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    security = FakeDeviceSecurity();
    reminders = FakeDailyReminder();
    preferences = AppPreferences(security: security, reminders: reminders);
    await preferences.loadUser('alice');
  });

  test('theme persists and is isolated between accounts', () async {
    await preferences.setDarkMode(true);
    expect(preferences.themeMode, ThemeMode.dark);
    await preferences.loadUser('bob');
    expect(preferences.themeMode, ThemeMode.light);
    await preferences.loadUser('alice');
    expect(preferences.themeMode, ThemeMode.dark);
  });

  test('canceling enrollment never enables app locking', () async {
    security.accepted = false;
    await expectLater(preferences.setBiometrics(true), throwsStateError);
    expect(preferences.biometrics, isFalse);
    final store = await SharedPreferences.getInstance();
    expect(store.getBool('settings.alice.biometrics'), isNull);
  });

  test(
    'lock recovery requires signout before resetting the device opt-in',
    () async {
      await preferences.setBiometrics(true);
      await expectLater(
        preferences.clearLockAfterSignOut('alice'),
        throwsStateError,
      );
      await preferences.loadUser(null);
      await preferences.clearLockAfterSignOut('alice');
      await preferences.loadUser('alice');
      expect(preferences.biometrics, isFalse);
      expect(preferences.locked, isFalse);
    },
  );

  test('canceling unlock keeps data locked, including after restart', () async {
    await preferences.setBiometrics(true);
    final restarted = AppPreferences(security: security, reminders: reminders);
    await restarted.loadUser('alice');
    expect(restarted.locked, isTrue);
    security.accepted = false;
    await restarted.unlock();
    expect(restarted.locked, isTrue);
    expect(restarted.authenticating, isFalse);
    security.accepted = true;
    await restarted.unlock();
    expect(restarted.locked, isFalse);
    security.accepted = false;
    await expectLater(restarted.setBiometrics(false), throwsStateError);
    expect(restarted.biometrics, isTrue);
  });

  test('an old authentication result cannot unlock another account', () async {
    await preferences.setBiometrics(true);
    await preferences.loadUser('bob');
    await preferences.setBiometrics(true);
    await preferences.loadUser('alice');
    security.pending = Completer<bool>();
    final unlocking = preferences.unlock();
    await preferences.loadUser('bob');
    security.pending!.complete(true);
    await unlocking;
    expect(preferences.userId, 'bob');
    expect(preferences.locked, isTrue);
  });

  test('permission failure leaves reminder disabled and unsaved', () async {
    reminders.denied = true;
    await expectLater(preferences.setReminder('20:30:00'), throwsStateError);
    expect(preferences.reminderTime, isNull);
    final store = await SharedPreferences.getInstance();
    expect(store.getString('settings.alice.reminder'), isNull);
  });

  test(
    'reminder restores silently and signout cancels the active schedule',
    () async {
      await preferences.setReminder('20:30:00');
      await preferences.setReminder('21:15:00');
      expect(reminders.scheduled, '21:15:00');
      await preferences.loadUser(null);
      expect(reminders.scheduled, isNull);
      expect(preferences.reminderTime, isNull);
      await preferences.loadUser('alice');
      expect(reminders.scheduled, '21:15:00');
      expect(reminders.permissionRequests.last, isFalse);
      await preferences.setReminder(null);
      expect(reminders.scheduled, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'settings.alice.reminder',
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'lifecycle lock hides financial content and canceled authentication stays locked',
    (tester) async {
      await preferences.setBiometrics(true);
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(
            preferences: preferences,
            child: const Scaffold(body: Text('Private balance')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private balance'), findsOneWidget);
      security.accepted = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('Private balance'), findsNothing);
      expect(find.text('Sổ tài chính đã khóa'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Private balance'), findsNothing);
      security.accepted = true;
      await tester.tap(find.text('Mở khóa'));
      await tester.pumpAndSettle();
      expect(find.text('Private balance'), findsOneWidget);
    },
  );
}
