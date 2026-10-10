import 'dart:convert';

import 'app_storage.dart';

class CompletedBooks {
  CompletedBooks._();
  static const _key = 'completedBooksJson';

  static Future<Map<String, int>> load() async {
    final prefs = await AppStorage.getInstance();
    final raw = prefs.getString(_key);
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

  static Future<bool> isCompleted(String bookId) async {
    final map = await load();
    return map.containsKey(bookId);
  }

  static Future<void> markComplete(String bookId, {String? review}) async {
    final prefs = await AppStorage.getInstance();
    final map = await load();
    map[bookId] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_key, jsonEncode(map));
    if (review != null && review.trim().isNotEmpty) {
      await prefs.setString('bookReview_$bookId', review.trim());
    }
  }

  static Future<void> unmark(String bookId) async {
    final prefs = await AppStorage.getInstance();
    final map = await load();
    map.remove(bookId);
    await prefs.setString(_key, jsonEncode(map));
  }

  static Future<String?> review(String bookId) async {
    final prefs = await AppStorage.getInstance();
    return prefs.getString('bookReview_$bookId');
  }
}
