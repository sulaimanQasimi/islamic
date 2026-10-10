import 'dart:convert';

import 'app_storage.dart';

/// Daily reading goal, logged minutes, and streak.
class ReadingGoals {
  ReadingGoals._();

  static const defaultGoalMinutes = 15;

  static String _dayKey([DateTime? at]) {
    final d = at ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static Future<int> goalMinutes() async {
    final prefs = await AppStorage.getInstance();
    return prefs.getInt('dailyGoalMinutes') ?? defaultGoalMinutes;
  }

  static Future<void> setGoalMinutes(int minutes) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setInt('dailyGoalMinutes', minutes.clamp(5, 240));
  }

  static Future<Map<String, int>> _minutesByDay(AppStorage prefs) async {
    final raw = prefs.getString('readingMinutesByDate');
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<int> todayMinutes() async {
    final prefs = await AppStorage.getInstance();
    final map = await _minutesByDay(prefs);
    return map[_dayKey()] ?? 0;
  }

  /// Adds reading seconds; updates streak when daily goal is newly met.
  static Future<({int today, int streak, bool goalJustMet})> addSeconds(
    int seconds,
  ) async {
    if (seconds <= 0) {
      final today = await todayMinutes();
      final streak = await currentStreak();
      return (today: today, streak: streak, goalJustMet: false);
    }
    final prefs = await AppStorage.getInstance();
    final map = await _minutesByDay(prefs);
    final day = _dayKey();
    final before = map[day] ?? 0;
    final addMin = (seconds / 60).ceil().clamp(1, 600);
    final after = before + addMin;
    map[day] = after;

    // Keep last ~60 days.
    final keys = map.keys.toList()..sort();
    if (keys.length > 60) {
      for (final k in keys.take(keys.length - 60)) {
        map.remove(k);
      }
    }
    await prefs.setString('readingMinutesByDate', jsonEncode(map));

    final goal = prefs.getInt('dailyGoalMinutes') ?? defaultGoalMinutes;
    final justMet = before < goal && after >= goal;
    final streak = await _recomputeStreak(prefs, map, goal);
    return (today: after, streak: streak, goalJustMet: justMet);
  }

  static Future<int> currentStreak() async {
    final prefs = await AppStorage.getInstance();
    final map = await _minutesByDay(prefs);
    final goal = prefs.getInt('dailyGoalMinutes') ?? defaultGoalMinutes;
    return _recomputeStreak(prefs, map, goal);
  }

  static Future<int> _recomputeStreak(
    AppStorage prefs,
    Map<String, int> map,
    int goal,
  ) async {
    var streak = 0;
    var cursor = DateTime.now();
    // If today not yet met, streak counts from yesterday.
    if ((map[_dayKey(cursor)] ?? 0) < goal) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (true) {
      final key = _dayKey(cursor);
      if ((map[key] ?? 0) >= goal) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
      if (streak > 400) break;
    }
    await prefs.setInt('readingStreak', streak);
    return streak;
  }

  static Future<({int today, int goal, int streak, double progress})>
      snapshot() async {
    final today = await todayMinutes();
    final goal = await goalMinutes();
    final streak = await currentStreak();
    return (
      today: today,
      goal: goal,
      streak: streak,
      progress: goal <= 0 ? 0.0 : (today / goal).clamp(0.0, 1.0),
    );
  }
}
