import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ConfigService {
  static String _baseUrl = '';

  /// Link đầu tiên trong app_config.json, đã bỏ dấu "/" ở cuối
  static String get baseUrl => _baseUrl;

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/app_config.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['base_urls'] as List).cast<String>();
    if (list.isEmpty) {
      throw StateError('app_config.json: base_urls đang rỗng');
    }
    _baseUrl = list.first.replaceAll(RegExp(r'/+$'), '');
  }
}
