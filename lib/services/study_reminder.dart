import '../data/daily_reflections.dart';
import 'app_storage.dart';
import 'daily_notification_service.dart';

class StudyReminder {
  StudyReminder._();

  static Future<bool> enabled() async {
    final prefs = await AppStorage.getInstance();
    return prefs.getBool('studyReminderEnabled') ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setBool('studyReminderEnabled', value);
    if (value) {
      await DailyNotificationService.requestPermission();
      await DailyNotificationService.reschedule();
    } else {
      await DailyNotificationService.cancelAllScheduled();
    }
  }

  static Future<(int hour, int minute)> time() async {
    final prefs = await AppStorage.getInstance();
    return (
      prefs.getInt('studyReminderHour') ?? 20,
      prefs.getInt('studyReminderMinute') ?? 0,
    );
  }

  static Future<void> setTime({required int hour, required int minute}) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setInt('studyReminderHour', hour.clamp(0, 23));
    await prefs.setInt('studyReminderMinute', minute.clamp(0, 59));
    if (await enabled()) {
      await DailyNotificationService.reschedule();
    }
  }

  static String _dayKey([DateTime? at]) {
    final d = at ?? DateTime.now();
    return '${d.year}-${d.month}-${d.day}';
  }

  /// Today's reflection for in-app nudge / preview.
  static DailyReflection todayReflection([DateTime? now]) =>
      reflectionForDate(now ?? DateTime.now());

  /// Returns true once per day when the reminder time has passed and
  /// the user hasn't been nudged yet today.
  static Future<bool> shouldNudge([DateTime? now]) async {
    if (!await enabled()) return false;
    final prefs = await AppStorage.getInstance();
    final at = now ?? DateTime.now();
    final (hour, minute) = await time();
    final due = DateTime(at.year, at.month, at.day, hour, minute);
    if (at.isBefore(due)) return false;
    final last = prefs.getString('studyReminderLastShown');
    if (last == _dayKey(at)) return false;
    return true;
  }

  static Future<void> markShown([DateTime? now]) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString('studyReminderLastShown', _dayKey(now));
  }

  /// Keep scheduled notifications fresh when the app opens.
  static Future<void> syncSchedule() async {
    await DailyNotificationService.init();
    if (await enabled()) {
      await DailyNotificationService.reschedule();
    }
  }
}
