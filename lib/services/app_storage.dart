import 'app_storage_native.dart'
    if (dart.library.html) 'app_storage_web.dart'
    as platform;

class AppStorage {
  AppStorage._();
  static Future<AppStorage> getInstance() async {
    await platform.initialize();
    return AppStorage._();
  }

  String? getString(String key) => platform.getString(key);
  List<String>? getStringList(String key) => platform.getStringList(key);
  int? getInt(String key) => platform.getInt(key);
  double? getDouble(String key) => platform.getDouble(key);
  bool containsKey(String key) => platform.containsKey(key);
  Future<void> setString(String key, String value) =>
      platform.setString(key, value);
  Future<void> setStringList(String key, List<String> value) =>
      platform.setStringList(key, value);
  Future<void> setInt(String key, int value) => platform.setInt(key, value);
  Future<void> setDouble(String key, double value) =>
      platform.setDouble(key, value);
}
