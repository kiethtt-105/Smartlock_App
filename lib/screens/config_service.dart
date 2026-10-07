import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart' show rootBundle;

class ConfigService {
  static List<String> _urls = [];
  static int _active = 0;

  /// Host của server đang dùng (hiện ở màn đăng nhập). Đổi khi app chuyển sang link dự phòng.
  static final ValueNotifier<String> serverHost = ValueNotifier('');

  /// Link đang dùng (mặc định là link đầu trong app_config.json), đã bỏ dấu "/" ở cuối.
  static String get baseUrl => _urls.isEmpty ? '' : _urls[_active];

  /// Toàn bộ link theo thứ tự ưu tiên.
  static List<String> get baseUrls => List.unmodifiable(_urls);

  static int get activeIndex => _active;

  static String hostOf(String url) {
    final h = Uri.tryParse(url)?.host ?? '';
    return h.isEmpty ? url : h;
  }

  static void setActive(int i) {
    if (i < 0 || i >= _urls.length) return;
    _active = i;
    serverHost.value = hostOf(_urls[i]);
  }

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/config/app_config.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['base_urls'] as List)
        .cast<String>()
        .map((e) => e.trim().replaceAll(RegExp(r'/+$'), ''))
        .where((e) => e.isNotEmpty)
        .toList();
    if (list.isEmpty) {
      throw StateError('app_config.json: base_urls đang rỗng');
    }
    _urls = list;
    setActive(0); // ưu tiên link đầu tiên
  }
}
