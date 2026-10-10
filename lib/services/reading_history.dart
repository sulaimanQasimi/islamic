import 'dart:convert';

import 'app_storage.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.bookId,
    required this.title,
    required this.author,
    required this.chapter,
    required this.atMs,
  });

  final String bookId;
  final String title;
  final String author;
  final int chapter;
  final int atMs;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'title': title,
        'author': author,
        'chapter': chapter,
        'atMs': atMs,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        bookId: json['bookId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        chapter: (json['chapter'] as num?)?.toInt() ?? 0,
        atMs: (json['atMs'] as num?)?.toInt() ?? 0,
      );
}

class ReadingHistory {
  ReadingHistory._();

  static const _key = 'readingHistory';
  static const _max = 80;

  static Future<List<HistoryEntry>> load() async {
    final prefs = await AppStorage.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.bookId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> record({
    required String bookId,
    required String title,
    required String author,
    required int chapter,
  }) async {
    final prefs = await AppStorage.getInstance();
    final items = await load();
    items.removeWhere((e) => e.bookId == bookId);
    items.insert(
      0,
      HistoryEntry(
        bookId: bookId,
        title: title,
        author: author,
        chapter: chapter,
        atMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    final trimmed = items.take(_max).toList();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString(_key, '[]');
  }
}
