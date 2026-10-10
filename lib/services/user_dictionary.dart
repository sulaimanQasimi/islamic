import 'dart:convert';

import 'app_storage.dart';
import 'dictionary_service.dart';

class UserDictionary {
  UserDictionary._();

  static const _key = 'userDictionaryJson';

  static Future<Map<String, String>> load() async {
    final prefs = await AppStorage.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries) e.key: e.value.toString(),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(Map<String, String> entries) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString(_key, jsonEncode(entries));
  }

  static Future<void> upsert(String word, String meaning) async {
    final key = DictionaryService.normalize(word);
    if (key.isEmpty || meaning.trim().isEmpty) return;
    final map = await load();
    map[key] = meaning.trim();
    await save(map);
  }

  static Future<void> remove(String word) async {
    final map = await load();
    map.remove(DictionaryService.normalize(word));
    await save(map);
  }

  static Future<String?> lookup(String raw) async {
    final key = DictionaryService.normalize(raw);
    if (key.isEmpty) return null;
    final custom = await load();
    if (custom.containsKey(key)) return custom[key];
    for (final e in custom.entries) {
      if (e.key.replaceAll('‌', '') == key.replaceAll('‌', '')) {
        return e.value;
      }
    }
    return DictionaryService.lookup(raw);
  }
}
