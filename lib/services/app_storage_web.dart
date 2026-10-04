import 'dart:convert';

import 'package:web/web.dart' as web;

Future<void> initialize() async {}
String? getString(String key) => web.window.localStorage.getItem(key);
List<String>? getStringList(String key) {
  final value = getString(key);
  if (value == null) return null;
  try {
    return (jsonDecode(value) as List<dynamic>).cast<String>();
  } catch (_) {
    return null;
  }
}

int? getInt(String key) => int.tryParse(getString(key) ?? '');
double? getDouble(String key) => double.tryParse(getString(key) ?? '');
bool? getBool(String key) {
  final value = getString(key);
  if (value == 'true') return true;
  if (value == 'false') return false;
  return null;
}

bool containsKey(String key) => getString(key) != null;
Future<void> setString(String key, String value) async =>
    web.window.localStorage.setItem(key, value);
Future<void> setStringList(String key, List<String> value) async =>
    web.window.localStorage.setItem(key, jsonEncode(value));
Future<void> setInt(String key, int value) async =>
    web.window.localStorage.setItem(key, '$value');
Future<void> setDouble(String key, double value) async =>
    web.window.localStorage.setItem(key, '$value');
Future<void> setBool(String key, bool value) async =>
    web.window.localStorage.setItem(key, '$value');
