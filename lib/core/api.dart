import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Thứ tự ưu tiên: link đầu; lỗi mạng / 502-504 / trả HTML => tự đua sang link sau.
const kBases = [
  'https://d81h6zk7-8000.asse.devtunnels.ms',
  'https://he-thong-cua-thong-minh-hp-iots.vercel.app',
];

class Res {
  final bool ok;
  final int status;
  final Map<String, dynamic> d;
  final String? etag;
  final bool net; // true = không chạm được server nào
  Res(this.ok, this.status, this.d, {this.etag, this.net = false});
  bool get notModified => status == 304;
  String get code => (d['error']?['code'] ?? '').toString();
  String get msg => net ? 'Không có kết nối tới máy chủ' : (d['error']?['message'] ?? 'Có lỗi xảy ra').toString();
}

class Api {
  static final i = Api._();
  Api._();
  final _s = const FlutterSecureStorage();
  String? access, refresh;
  int _b = 0; // base đang chạy tốt
  Future<bool>? _refreshing;
  void Function()? onLoggedOut;

  Future<void> init() async {
    access = await _s.read(key: 'at');
    refresh = await _s.read(key: 'rt');
  }

  bool get hasSession => refresh != null;

  Future<void> save(Map d) async {
    access = d['access_token'];
    refresh = d['refresh_token'] ?? refresh;
    await _s.write(key: 'at', value: access);
    await _s.write(key: 'rt', value: refresh);
  }

  Future<void> clear() async {
    access = refresh = null;
    await _s.deleteAll();
  }

  Future<Res> call(String m, String path,
      {Map? body, String? etag, bool auth = true, bool retry = true}) async {
    for (var k = 0; k < kBases.length; k++) {
      final bi = (_b + k) % kBases.length;
      try {
        final uri = Uri.parse('${kBases[bi]}/api/app/$path');
        final h = {
          'Content-Type': 'application/json',
          if (auth && access != null) 'Authorization': 'Bearer $access',
          if (etag != null) 'If-None-Match': etag,
        };
        final req = http.Request(m, uri)..headers.addAll(h);
        if (body != null) req.body = jsonEncode(body);
        final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 8)));
        if (r.statusCode == 304) {
          _b = bi;
          return Res(true, 304, {}, etag: etag);
        }
        final isJson = (r.headers['content-type'] ?? '').contains('json');
        if (!isJson || (r.statusCode >= 502 && r.statusCode <= 504)) continue; // base này hỏng -> thử base kế
        _b = bi;
        final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        if (r.statusCode == 401 && auth && retry && refresh != null) {
          if (await _refresh()) return call(m, path, body: body, etag: etag, auth: auth, retry: false);
        }
        return Res(r.statusCode < 400 && d['ok'] != false, r.statusCode, d, etag: r.headers['etag']);
      } catch (_) {
        continue;
      }
    }
    return Res(false, 0, {}, net: true);
  }

  /// Một lần refresh duy nhất dù nhiều request cùng 401.
  Future<bool> _refresh() => _refreshing ??= (() async {
        try {
          final r = await call('POST', 'auth/refresh/', body: {'refresh_token': refresh}, auth: false, retry: false);
          if (r.ok) {
            await save(r.d);
            return true;
          }
          if (!r.net && r.status >= 400 && r.status < 500) {
            await clear();
            onLoggedOut?.call(); // chỉ đá ra khi refresh bị TỪ CHỐI, mất mạng thì giữ phiên
          }
          return false;
        } finally {
          _refreshing = null;
        }
      })();

  static const _dev = {'platform': 'android', 'device_name': 'Android', 'app_version': '1.0.0'};

  /// Trả Res; nếu có access_token thì đã lưu. d['two_factor_required'] == true => cần bước 2FA.
  Future<Res> login(String id, String pw) async {
    final r = await call('POST', 'auth/login/', body: {'identifier': id, 'password': pw, ..._dev}, auth: false);
    if (r.ok && r.d['access_token'] != null) await save(r.d);
    return r;
  }

  Future<Res> verify2fa(String token, String method, String code) async {
    final r = await call('POST', 'auth/2fa/verify/',
        body: {'challenge_token': token, 'method': method, 'code': code}, auth: false);
    if (r.ok && r.d['access_token'] != null) await save(r.d);
    return r;
  }

  Future<void> logout() async {
    await call('POST', 'auth/logout/', body: {});
    await clear();
  }
}
