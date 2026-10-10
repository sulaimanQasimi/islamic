import 'app_storage.dart';

/// Schedule-based night mode (app theme + reader palette hint).
class NightAuto {
  NightAuto._();

  static Future<bool> enabled() async {
    final prefs = await AppStorage.getInstance();
    return prefs.getBool('nightAutoEnabled') ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setBool('nightAutoEnabled', value);
  }

  static Future<(int startHour, int endHour)> window() async {
    final prefs = await AppStorage.getInstance();
    return (
      prefs.getInt('nightStartHour') ?? 19,
      prefs.getInt('nightEndHour') ?? 6,
    );
  }

  static Future<void> setWindow({
    required int startHour,
    required int endHour,
  }) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setInt('nightStartHour', startHour.clamp(0, 23));
    await prefs.setInt('nightEndHour', endHour.clamp(0, 23));
  }

  /// True when current local hour is inside the night window.
  /// Window may wrap past midnight (e.g. 19 → 6).
  static bool isNightHour(int hour, int startHour, int endHour) {
    if (startHour == endHour) return false;
    if (startHour < endHour) {
      return hour >= startHour && hour < endHour;
    }
    return hour >= startHour || hour < endHour;
  }

  static Future<bool> isNightNow([DateTime? now]) async {
    if (!await enabled()) return false;
    final (start, end) = await window();
    final hour = (now ?? DateTime.now()).hour;
    return isNightHour(hour, start, end);
  }

  /// Reader palette index for night (matches reader `_palettes` night = 2).
  static const readerNightThemeIndex = 2;
}
