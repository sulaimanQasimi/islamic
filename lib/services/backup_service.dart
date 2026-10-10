import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'app_storage.dart';
import 'share_helper.dart';

/// Backup / restore of local reading data (prefs JSON zip).
class BackupService {
  BackupService._();

  static const _backupKeys = <String>[
    'favoriteBooks',
    'readingHistory',
    'readingMinutesByDate',
    'dailyGoalMinutes',
    'readingStreak',
    'bookCollections',
    'notebookFreeNotes',
    'userDictionaryJson',
    'studyPlansJson',
    'completedBooksJson',
    'appThemeMode',
    'nightAutoEnabled',
    'nightStartHour',
    'nightEndHour',
    'studyReminderEnabled',
    'studyReminderHour',
    'studyReminderMinute',
    'readerFontSize',
    'readerLineHeight',
    'readerTheme',
    'readerAlign',
    'libraryGridView',
    'launchLastBook',
    'opdsFeedUrl',
  ];

  static Future<Map<String, dynamic>> collect(AppStorage prefs) async {
    final data = <String, dynamic>{
      'version': 1,
      'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
      'values': <String, dynamic>{},
      'stringLists': <String, dynamic>{},
    };
    final values = data['values'] as Map<String, dynamic>;
    final lists = data['stringLists'] as Map<String, dynamic>;

    for (final key in _backupKeys) {
      if (!prefs.containsKey(key)) continue;
      final list = prefs.getStringList(key);
      if (list != null) {
        lists[key] = list;
        continue;
      }
      final s = prefs.getString(key);
      if (s != null) {
        values[key] = s;
        continue;
      }
      final i = prefs.getInt(key);
      if (i != null) {
        values[key] = i;
        continue;
      }
      final d = prefs.getDouble(key);
      if (d != null) {
        values[key] = d;
        continue;
      }
      final b = prefs.getBool(key);
      if (b != null) values[key] = b;
    }

    // Per-book keys: progress, highlights, bookmarks, reviews
    // SharedPreferences doesn't expose all keys via AppStorage — use known book ids from history/favorites.
    return data;
  }

  static Future<Uint8List> buildZip({
    required Map<String, dynamic> payload,
    Map<String, String>? perBookJson,
  }) async {
    final archive = Archive();
    final main = utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));
    archive.addFile(ArchiveFile('marefat_backup.json', main.length, main));
    if (perBookJson != null) {
      for (final e in perBookJson.entries) {
        final bytes = utf8.encode(e.value);
        archive.addFile(ArchiveFile('books/${e.key}.json', bytes.length, bytes));
      }
    }
    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded ?? []);
  }

  static Future<void> exportAndShare({
    required List<String> bookIds,
  }) async {
    final prefs = await AppStorage.getInstance();
    final payload = await collect(prefs);
    final perBook = <String, String>{};
    for (final id in bookIds) {
      final map = <String, dynamic>{
        'progress': prefs.getInt('progress_$id'),
        'chapterCount': prefs.getInt('chapterCount_$id'),
        'bookmarks': prefs.getStringList('bookmarks_$id'),
        'highlights': prefs.getString('highlights_json_$id'),
        'review': prefs.getString('bookReview_$id'),
      };
      perBook[id] = jsonEncode(map);
    }
    final zip = await buildZip(payload: payload, perBookJson: perBook);
    final name =
        'Marefat_backup_${DateTime.now().toIso8601String().split('T').first}.zip';
    await ShareHelper.shareBytesAsFile(
      bytes: zip,
      fileName: name,
      mimeType: 'application/zip',
      subject: 'پشتیبان معرفت',
      text: 'فایل پشتیبان دادهٔ مطالعه در معرفت',
    );
  }

  static Future<int> restoreFromJsonMap(Map<String, dynamic> data) async {
    final prefs = await AppStorage.getInstance();
    var count = 0;
    final values = data['values'];
    if (values is Map) {
      for (final e in values.entries) {
        final key = e.key.toString();
        final v = e.value;
        if (v is String) {
          await prefs.setString(key, v);
          count++;
        } else if (v is int) {
          await prefs.setInt(key, v);
          count++;
        } else if (v is double) {
          await prefs.setDouble(key, v);
          count++;
        } else if (v is bool) {
          await prefs.setBool(key, v);
          count++;
        } else if (v is num) {
          await prefs.setInt(key, v.toInt());
          count++;
        }
      }
    }
    final lists = data['stringLists'];
    if (lists is Map) {
      for (final e in lists.entries) {
        final list = (e.value as List<dynamic>?)?.map((x) => x.toString()).toList();
        if (list != null) {
          await prefs.setStringList(e.key.toString(), list);
          count++;
        }
      }
    }
    return count;
  }

  static Future<int> restoreZipBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    var count = 0;
    final prefs = await AppStorage.getInstance();
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final content = utf8.decode(file.content as List<int>);
      if (file.name == 'marefat_backup.json') {
        final map = jsonDecode(content) as Map<String, dynamic>;
        count += await restoreFromJsonMap(map);
      } else if (file.name.startsWith('books/') && file.name.endsWith('.json')) {
        final id = file.name.substring(6, file.name.length - 5);
        final map = jsonDecode(content) as Map<String, dynamic>;
        final progress = map['progress'];
        if (progress is num) {
          await prefs.setInt('progress_$id', progress.toInt());
          count++;
        }
        final chapters = map['chapterCount'];
        if (chapters is num) {
          await prefs.setInt('chapterCount_$id', chapters.toInt());
          count++;
        }
        final bookmarks = map['bookmarks'];
        if (bookmarks is List) {
          await prefs.setStringList(
            'bookmarks_$id',
            bookmarks.map((e) => e.toString()).toList(),
          );
          count++;
        }
        final highlights = map['highlights'];
        if (highlights is String && highlights.isNotEmpty) {
          await prefs.setString('highlights_json_$id', highlights);
          count++;
        }
        final review = map['review'];
        if (review is String && review.isNotEmpty) {
          await prefs.setString('bookReview_$id', review);
          count++;
        }
      }
    }
    return count;
  }
}
