import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu access/refresh token trong kho an toàn của Android (Keystore).
class TokenStore {
  static const _s = FlutterSecureStorage();

  static Future<void> save({
    required String access,
    required String refresh,
    required DateTime accessExp,
  }) async {
    await _s.write(key: 'access', value: access);
    await _s.write(key: 'refresh', value: refresh);
    await _s.write(key: 'exp', value: accessExp.millisecondsSinceEpoch.toString());
  }

  static Future<Map<String, String?>> read() async => {
        'access': await _s.read(key: 'access'),
        'refresh': await _s.read(key: 'refresh'),
        'exp': await _s.read(key: 'exp'),
      };

  static Future<void> clear() => _s.deleteAll();
}
