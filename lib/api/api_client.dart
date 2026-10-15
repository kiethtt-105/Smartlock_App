import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'token_store.dart';

/// Lỗi nghiệp vụ do server trả về: {"ok": false, "error": {"code", "message"}}
class ApiException implements Exception {
  final String code;
  final String message;
  final int status;
  final Map<String, dynamic> extra;

  ApiException(this.code, this.message, this.status, [this.extra = const {}]);

  @override
  String toString() => message;
}

class _NetworkFailure implements Exception {
  final String why;
  _NetworkFailure(this.why);
}

/// HTTP client dùng chung:
///  - gắn Bearer token, tự refresh khi access token hết hạn (15 phút)
///  - tự chuyển sang server dự phòng khi server chính không kết nối được
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  String? _access;
  String? _refresh;
  DateTime? _accessExp;
  DateTime? _primaryDownUntil;
  Future<void>? _refreshing;

  /// Gọi khi phiên bị thu hồi / refresh token hỏng -> UI quay về màn hình đăng nhập.
  void Function()? onSessionLost;

  /// Server đã trả lời thành công gần nhất (để hiển thị/debug).
  String activeBase = ApiConfig.primary;

  bool get hasSession => _refresh != null;

  // ───────────────────────── token ─────────────────────────

  Future<void> loadTokens() async {
    final t = await TokenStore.read();
    _access = t['access'];
    _refresh = t['refresh'];
    final ms = int.tryParse(t['exp'] ?? '');
    _accessExp = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setTokens(Map<String, dynamic> j) async {
    _access = j['access_token'] as String;
    _refresh = j['refresh_token'] as String;
    final ttl = (j['expires_in'] as num?)?.toInt() ?? 900;
    _accessExp = DateTime.now().add(Duration(seconds: ttl - 30));
    await TokenStore.save(access: _access!, refresh: _refresh!, accessExp: _accessExp!);
  }

  Future<void> clearTokens() async {
    _access = null;
    _refresh = null;
    _accessExp = null;
    await TokenStore.clear();
  }

  // ───────────────────────── public ─────────────────────────

  Future<Map<String, dynamic>> get(String path,
          {Map<String, dynamic>? query, bool auth = true}) =>
      _request('GET', path, query: query, auth: auth);

  Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body, Map<String, dynamic>? query, bool auth = true}) =>
      _request('POST', path, body: body ?? {}, query: query, auth: auth);

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) =>
      _request('PUT', path, body: body ?? {});

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body ?? {});

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? body}) =>
      _request('DELETE', path, body: body);

  // ───────────────────────── core ─────────────────────────

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    if (auth && _refresh != null && _accessExp != null && DateTime.now().isAfter(_accessExp!)) {
      await _refreshTokens();
    }
    try {
      return await _send(method, path, query, body, auth);
    } on ApiException catch (e) {
      if (auth && e.status == 401) {
        if (e.code == 'TOKEN_EXPIRED' && _refresh != null) {
          await _refreshTokens();
          return _send(method, path, query, body, auth);
        }
        if (const ['SESSION_REVOKED', 'TOKEN_INVALID', 'UNAUTHENTICATED'].contains(e.code)) {
          await _dropSession();
        }
      }
      rethrow;
    }
  }

  Future<void> _dropSession() async {
    await clearTokens();
    onSessionLost?.call();
  }

  Future<void> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    final rt = _refresh;
    if (rt == null) {
      throw ApiException('UNAUTHENTICATED', 'Bạn chưa đăng nhập.', 401);
    }
    try {
      final j = await _send('POST', '/auth/refresh/', null, {'refresh_token': rt}, false);
      await setTokens(j);
    } on ApiException catch (e) {
      if (e.code == 'REFRESH_CONFLICT') {
        await loadTokens(); // token vừa được đổi ở nơi khác, dùng bản mới nhất đã lưu
        return;
      }
      if (e.status == 401 || e.status == 403) await _dropSession();
      rethrow;
    }
  }

  List<String> _baseOrder() {
    final down = _primaryDownUntil;
    if (down != null && DateTime.now().isBefore(down)) {
      return [ApiConfig.fallback, ApiConfig.primary];
    }
    return [ApiConfig.primary, ApiConfig.fallback];
  }

  Future<Map<String, dynamic>> _send(String method, String path, Map<String, dynamic>? query,
      Map<String, dynamic>? body, bool auth) async {
    for (final base in _baseOrder()) {
      try {
        final r = await _once(base, method, path, query, body, auth);
        if (base == ApiConfig.primary) _primaryDownUntil = null;
        activeBase = base;
        return r;
      } on _NetworkFailure {
        if (base == ApiConfig.primary) {
          _primaryDownUntil = DateTime.now().add(ApiConfig.primaryRetryAfter);
        }
      }
    }
    throw ApiException('NETWORK',
        'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.', 0);
  }

  Future<Map<String, dynamic>> _once(String base, String method, String path,
      Map<String, dynamic>? query, Map<String, dynamic>? body, bool auth) async {
    var uri = Uri.parse('$base/api/app$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query.map((k, v) => MapEntry(k, v.toString())));
    }
    final req = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        // Dev Tunnel: bỏ trang cảnh báo lừa đảo, trả thẳng JSON.
        'X-Tunnel-Skip-AntiPhishing-Page': 'true',
        if (auth && _access != null) 'Authorization': 'Bearer $_access',
      });
    if (body != null) req.body = jsonEncode(body);

    http.Response res;
    try {
      final streamed = await _http.send(req).timeout(ApiConfig.timeout);
      res = await http.Response.fromStream(streamed).timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw _NetworkFailure('timeout');
    } on SocketException catch (e) {
      throw _NetworkFailure(e.message);
    } on HandshakeException catch (e) {
      throw _NetworkFailure(e.message);
    } on http.ClientException catch (e) {
      throw _NetworkFailure(e.message);
    }

    Map<String, dynamic>? json;
    if ((res.headers['content-type'] ?? '').contains('json')) {
      try {
        json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {}
    }
    // Không phải JSON (trang lỗi của tunnel/Vercel...) -> coi như server này không dùng được.
    if (json == null) throw _NetworkFailure('non-json ${res.statusCode}');

    if (json['ok'] == true) return json;

    final err = (json['error'] as Map?)?.cast<String, dynamic>() ?? {};
    throw ApiException(
      (err['code'] ?? 'ERROR').toString(),
      (err['message'] ?? 'Có lỗi xảy ra.').toString(),
      res.statusCode,
      err,
    );
  }
}
