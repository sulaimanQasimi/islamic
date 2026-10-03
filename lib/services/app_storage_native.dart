import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? _preferences;

Future<void> initialize() async {
  _preferences ??= await SharedPreferences.getInstance();
}

SharedPreferences get _prefs => _preferences!;
String? getString(String key) => _prefs.getString(key);
List<String>? getStringList(String key) => _prefs.getStringList(key);
int? getInt(String key) => _prefs.getInt(key);
double? getDouble(String key) => _prefs.getDouble(key);
bool containsKey(String key) => _prefs.containsKey(key);
Future<void> setString(String key, String value) async {
  await _prefs.setString(key, value);
}

Future<void> setStringList(String key, List<String> value) async {
  await _prefs.setStringList(key, value);
}

Future<void> setInt(String key, int value) async {
  await _prefs.setInt(key, value);
}

Future<void> setDouble(String key, double value) async {
  await _prefs.setDouble(key, value);
}
