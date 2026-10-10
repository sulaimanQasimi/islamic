import 'dart:convert';

import '../models/text_highlight.dart';
import 'app_storage.dart';

class NotebookEntry {
  const NotebookEntry({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapter,
    required this.text,
    this.note,
    required this.createdAtMs,
    this.fromHighlight = true,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final int chapter;
  final String text;
  final String? note;
  final int createdAtMs;
  final bool fromHighlight;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'bookTitle': bookTitle,
        'chapter': chapter,
        'text': text,
        if (note != null) 'note': note,
        'createdAtMs': createdAtMs,
        'fromHighlight': fromHighlight,
      };

  factory NotebookEntry.fromJson(Map<String, dynamic> json) => NotebookEntry(
        id: json['id'] as String? ?? '',
        bookId: json['bookId'] as String? ?? '',
        bookTitle: json['bookTitle'] as String? ?? '',
        chapter: (json['chapter'] as num?)?.toInt() ?? 0,
        text: json['text'] as String? ?? '',
        note: json['note'] as String?,
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
        fromHighlight: json['fromHighlight'] as bool? ?? false,
      );
}

class NotebookStore {
  NotebookStore._();

  static const _freeKey = 'notebookFreeNotes';

  static Future<List<NotebookEntry>> loadFreeNotes() async {
    final prefs = await AppStorage.getInstance();
    final raw = prefs.getString(_freeKey);
    if (raw == null || raw.isEmpty) return <NotebookEntry>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => NotebookEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <NotebookEntry>[];
    }
  }

  static Future<void> saveFreeNotes(List<NotebookEntry> notes) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString(
      _freeKey,
      jsonEncode(notes.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> addFreeNote({
    required String bookId,
    required String bookTitle,
    required int chapter,
    required String text,
    String? note,
  }) async {
    final notes = List<NotebookEntry>.from(await loadFreeNotes());
    notes.insert(
      0,
      NotebookEntry(
        id: 'n_${DateTime.now().microsecondsSinceEpoch}',
        bookId: bookId,
        bookTitle: bookTitle,
        chapter: chapter,
        text: text.trim(),
        note: note?.trim().isEmpty == true ? null : note?.trim(),
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        fromHighlight: false,
      ),
    );
    await saveFreeNotes(notes);
  }

  static Future<void> deleteFreeNote(String id) async {
    final notes = List<NotebookEntry>.from(await loadFreeNotes());
    notes.removeWhere((n) => n.id == id);
    await saveFreeNotes(notes);
  }

  /// Aggregates highlight notes for known books + free notes.
  static Future<List<NotebookEntry>> loadAll({
    required Map<String, String> bookTitles,
  }) async {
    final prefs = await AppStorage.getInstance();
    final fromHighlights = <NotebookEntry>[];

    for (final entry in bookTitles.entries) {
      final raw = prefs.getString('highlights_json_${entry.key}');
      final highlights = TextHighlight.decodeList(raw);
      for (final h in highlights) {
        if ((h.note == null || h.note!.trim().isEmpty) && h.text.isEmpty) {
          continue;
        }
        // Include all highlights that have a note, plus all highlights as study items.
        fromHighlights.add(
          NotebookEntry(
            id: 'hl_${entry.key}_${h.id}',
            bookId: entry.key,
            bookTitle: entry.value,
            chapter: h.chapter,
            text: h.text,
            note: h.note,
            createdAtMs: h.createdAtMs,
            fromHighlight: true,
          ),
        );
      }
    }

    final free = await loadFreeNotes();
    final all = [...fromHighlights, ...free]
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    return all;
  }

  static String exportText(List<NotebookEntry> entries) {
    final buf = StringBuffer('دفترچهٔ معرفت\n');
    buf.writeln('—'.padRight(24, '—'));
    for (final e in entries) {
      buf.writeln();
      buf.writeln('📚 ${e.bookTitle} · فصل ${e.chapter + 1}');
      buf.writeln(e.text);
      if (e.note != null && e.note!.isNotEmpty) {
        buf.writeln('یادداشت: ${e.note}');
      }
      buf.writeln('—');
    }
    return buf.toString();
  }
}
