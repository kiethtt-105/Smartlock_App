import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';

/// Tất cả đường dẫn API của app (đã đối chiếu với smartlock/api/app/urls.py).
class Endpoints {
  // auth
  static const login = '/api/app/auth/login/';
  static const register = '/api/app/auth/register/';
  static const twoFaVerify = '/api/app/auth/2fa/verify/';
  static const twoFaEmailSend = '/api/app/auth/2fa/email/send/';
  static const refresh = '/api/app/auth/refresh/';
  static const logout = '/api/app/auth/logout/';
  static const passwordReset = '/api/app/auth/password-reset/';
  // tài khoản
  static const me = '/api/app/me/';
  static const changePassword = '/api/app/me/password/';
  static const sessions = '/api/app/me/sessions/';
  static String sessionRevoke(String id) => '/api/app/me/sessions/$id/';
  static const pushToken = '/api/app/me/push-token/';
  // dữ liệu
  static const snapshot = '/api/app/snapshot/';
  static const devices = '/api/app/devices/';
  static String deviceCommand(String id) => '/api/app/devices/$id/commands/';
  static const deviceClaim = '/api/app/devices/claim/';
  static String devicePins(String id) => '/api/app/devices/$id/pins/';
  static String pin(String id) => '/api/app/pins/$id/';
  static String deviceCards(String id) => '/api/app/devices/$id/cards/';
  static String card(String id) => '/api/app/cards/$id/';
  static String face(String id) => '/api/app/faces/$id/';
  static String deviceShares(String id) => '/api/app/devices/$id/shares/';
  static String share(String id) => '/api/app/shares/$id/';
  static String shareLeave(String id) => '/api/app/shares/$id/leave/';
  static String device(String id) => '/api/app/devices/$id/';
  static const twoFaTotpBegin = '/api/app/me/two-factor/totp/begin/';
  static const twoFaTotpConfirm = '/api/app/me/two-factor/totp/confirm/';
  static const twoFaEmailSetupSend = '/api/app/me/two-factor/email/send/';
  static const twoFaEmailSetupConfirm = '/api/app/me/two-factor/email/confirm/';
  static String twoFaRemove(String m) => '/api/app/me/two-factor/methods/$m/remove/';
  static const notificationsRead = '/api/app/notifications/read/';
  static String notificationDelete(String id) => '/api/app/notifications/$id/';
}

class ApiException implements Exception {
  final String code, message;
  final int status;
  ApiException(this.message, {this.code = 'ERROR', this.status = 0});
  bool get isNetwork => status == 0;
  bool get isAuth => status == 401 || status == 403;
  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// Chuẩn phản hồi của backend: { ok: true, ... } hoặc { ok: false, error: { code, message } }
class ApiClient {
  static const _timeout = Duration(seconds: 15);
  final _storage = const FlutterSecureStorage();
  String? _access, _refresh, _etag;
  Future<bool>? _refreshing;

  /// Gọi khi refresh token cũng hết hạn -> AuthState đưa người dùng về màn đăng nhập.
  void Function()? onSessionExpired;

  bool get hasToken => _access != null || _refresh != null;

  Future<void> loadTokens() async {
    _access = await _storage.read(key: 'access_token');
    _refresh = await _storage.read(key: 'refresh_token');
  }

  Future<void> saveTokens(String access, String? refresh) async {
    _access = access;
    if (refresh != null) _refresh = refresh;
    await _storage.write(key: 'access_token', value: access);
    if (refresh != null) await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    _access = _refresh = _etag = null;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Uri _uriFor(String base, String path, [Map<String, String>? q]) => Uri.parse('$base$path').replace(queryParameters: q);

  Future<http.Response> _send(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query, bool auth = true, Map<String, String>? extra}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (auth && _access != null) 'Authorization': 'Bearer $_access',
      ...?extra,
    };
    final enc = body == null ? null : jsonEncode(body);
    final urls = ConfigService.baseUrls;
    // Thử link đang dùng trước, rồi tới các link còn lại (chỉ khi lỗi mạng/timeout).
    final order = [
      ConfigService.activeIndex,
      for (var i = 0; i < urls.length; i++)
        if (i != ConfigService.activeIndex) i,
    ];
    var timedOut = false;
    for (final i in order) {
      try {
        final u = _uriFor(urls[i], path, query);
        final Future<http.Response> f = switch (method) {
          'GET' => http.get(u, headers: headers),
          'DELETE' => http.delete(u, headers: headers, body: enc),
          'PUT' => http.put(u, headers: headers, body: enc),
          'PATCH' => http.patch(u, headers: headers, body: enc),
          _ => http.post(u, headers: headers, body: enc),
        };
        final res = await f.timeout(_timeout);
        ConfigService.setActive(i);
        return res;
      } on TimeoutException {
        timedOut = true;
      } catch (_) {
        timedOut = false;
      }
    }
    final host = ConfigService.serverHost.value;
    if (timedOut) throw ApiException('Máy chủ phản hồi quá lâu ($host).', code: 'TIMEOUT');
    throw ApiException('Không thể kết nối máy chủ ($host).', code: 'NETWORK');
  }

  Map<String, dynamic> _parse(http.Response r) {
    Map<String, dynamic> data = {};
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map<String, dynamic>) data = d;
    } catch (_) {}
    if (r.statusCode >= 400 || data['ok'] == false) {
      final err = data['error'];
      final msg = (err is Map ? err['message'] : null) ?? data['detail'] ?? 'Không thực hiện được (${r.statusCode}).';
      final code = (err is Map ? err['code'] : null) ?? 'ERROR';
      throw ApiException('$msg', code: '$code', status: r.statusCode);
    }
    return data;
  }

  Future<Map<String, dynamic>> request(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query, bool auth = true}) async {
    var r = await _send(method, path, body: body, query: query, auth: auth);
    if (r.statusCode == 401 && auth && _refresh != null && await _tryRefresh()) {
      r = await _send(method, path, body: body, query: query, auth: auth);
    }
    if (r.statusCode == 401 && auth && _access != null) {
      await clearTokens();
      onSessionExpired?.call();
    }
    return _parse(r);
  }

  /// Snapshot có ETag: server trả 304 khi không đổi -> trả null.
  Future<Map<String, dynamic>?> snapshot({bool force = false}) async {
    final extra = (!force && _etag != null) ? {'If-None-Match': _etag!} : null;
    var r = await _send('GET', Endpoints.snapshot, extra: extra);
    if (r.statusCode == 401 && _refresh != null && await _tryRefresh()) {
      r = await _send('GET', Endpoints.snapshot, extra: extra);
    }
    if (r.statusCode == 304) return null;
    if (r.statusCode == 401) {
      await clearTokens();
      onSessionExpired?.call();
    }
    final data = _parse(r);
    _etag = r.headers['etag'];
    return data;
  }

  Future<bool> _tryRefresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    try {
      final r = await _send('POST', Endpoints.refresh, body: {'refresh_token': _refresh}, auth: false);
      final d = _parse(r);
      final a = d['access_token'];
      if (a is! String) return false;
      await saveTokens(a, d['refresh_token'] as String?);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final api = ApiClient();
