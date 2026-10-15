import 'package:shared_preferences/shared_preferences.dart';

/// Cài đặt cục bộ trên máy (không đồng bộ lên server).
class AppPrefs {
  static Future<bool> getBool(String key, {bool def = true}) async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? def;

  static Future<void> setBool(String key, bool v) async =>
      (await SharedPreferences.getInstance()).setBool(key, v);

  static const sound = 'sound';
  static const tapToUnlock = 'tap_to_unlock';
  static const personalized = 'personalized';
}
