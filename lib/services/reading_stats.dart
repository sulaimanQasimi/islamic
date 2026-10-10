import 'dart:convert';

import 'app_storage.dart';
import 'completed_books.dart';
import 'reading_goals.dart';
import 'reading_history.dart';

class ReadingStatsSnapshot {
  const ReadingStatsSnapshot({
    required this.todayMinutes,
    required this.weekMinutes,
    required this.streak,
    required this.goal,
    required this.completedCount,
    required this.historyCount,
    required this.byDay,
  });

  final int todayMinutes;
  final int weekMinutes;
  final int streak;
  final int goal;
  final int completedCount;
  final int historyCount;
  final Map<String, int> byDay;
}

class ReadingStats {
  ReadingStats._();

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<ReadingStatsSnapshot> load() async {
    final prefs = await AppStorage.getInstance();
    final raw = prefs.getString('readingMinutesByDate');
    var byDay = <String, int>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        byDay = {
          for (final e in map.entries) e.key: (e.value as num).toInt(),
        };
      } catch (_) {}
    }
    final today = byDay[_dayKey(DateTime.now())] ?? 0;
    var week = 0;
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      week += byDay[_dayKey(now.subtract(Duration(days: i)))] ?? 0;
    }
    final goal = await ReadingGoals.goalMinutes();
    final streak = await ReadingGoals.currentStreak();
    final completed = await CompletedBooks.load();
    final history = await ReadingHistory.load();
    return ReadingStatsSnapshot(
      todayMinutes: today,
      weekMinutes: week,
      streak: streak,
      goal: goal,
      completedCount: completed.length,
      historyCount: history.length,
      byDay: byDay,
    );
  }
}
