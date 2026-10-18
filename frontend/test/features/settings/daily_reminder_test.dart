import 'package:flutter_test/flutter_test.dart';
import 'package:project_one/features/settings/services/daily_reminder.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();
  test('next reminder uses local calendar day across month boundaries', () {
    final zone = tz.getLocation('Asia/Ho_Chi_Minh');
    final now = tz.TZDateTime(zone, 2026, 10, 31, 21);
    final next = DailyReminder.nextOccurrence('20:30:00', now);
    expect(next, tz.TZDateTime(zone, 2026, 11, 1, 20, 30));
    expect(
      DailyReminder.nextOccurrence('22:00', now),
      tz.TZDateTime(zone, 2026, 10, 31, 22),
    );
  });
  test('next day remains at selected wall-clock time when DST changes', () {
    final zone = tz.getLocation('America/New_York');
    final now = tz.TZDateTime(zone, 2026, 10, 31, 21);
    final next = DailyReminder.nextOccurrence('20:30:00', now);
    expect(next.hour, 20);
    expect(next.day, 1);
    expect(next.difference(now), const Duration(hours: 24, minutes: 30));
  });
  test('invalid time cannot silently normalize into another day', () {
    for (final value in ['24:00', '20:60', 'bad', '20', '20:30:59']) {
      expect(
        () => DailyReminder.nextOccurrence(value, tz.TZDateTime.now(tz.UTC)),
        throwsArgumentError,
      );
    }
  });
}
