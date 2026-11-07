import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/daily_reflections.dart';
import 'app_storage.dart';

/// Schedules rotating daily OS notifications from [dailyReflections].
class DailyNotificationService {
  DailyNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'marefat_daily_reflections';
  static const _channelName = 'تأملات روزانه معرفت';
  static const _notifBaseId = 4200;
  static const _daysAhead = 60;
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'پیام روزانه از جام و میگر',
        importance: Importance.high,
      ),
    );

    _ready = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  static Future<(int hour, int minute)> time() async {
    final prefs = await AppStorage.getInstance();
    return (
      prefs.getInt('studyReminderHour') ?? 20,
      prefs.getInt('studyReminderMinute') ?? 0,
    );
  }

  static Future<bool> enabled() async {
    final prefs = await AppStorage.getInstance();
    return prefs.getBool('studyReminderEnabled') ?? false;
  }

  static Future<void> cancelAllScheduled() async {
    await init();
    for (var i = 0; i < _daysAhead; i++) {
      await _plugin.cancel(_notifBaseId + i);
    }
  }

  /// Schedule the next [_daysAhead] daily reflections at the reminder time.
  static Future<void> reschedule() async {
    await init();
    await cancelAllScheduled();
    if (!await enabled()) return;
    if (kIsWeb) return;

    final (hour, minute) = await time();
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'پیام روزانه از جام و میگر',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    for (var i = 0; i < _daysAhead; i++) {
      final when = next.add(Duration(days: i));
      final item = reflectionForDate(when);
      final body = '${item.notificationBody}\n— ${item.source}';
      await _plugin.zonedSchedule(
        _notifBaseId + i,
        item.title,
        body,
        when,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'پیام روزانه از جام و میگر',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: details.iOS,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
