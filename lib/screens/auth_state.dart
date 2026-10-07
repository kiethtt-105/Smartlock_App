import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'push_service.dart';
import 'store.dart';

enum AuthStatus { unknown, loggedOut, needTwoFa, loggedIn }

class AuthState extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;

  String? _challenge;
  List<String> twoFaMethods = const ['totp'];
  String twoFaMethod = 'totp';
  String? maskedEmail;

  /// Splash: nạp token đã lưu, thử gọi snapshot để biết còn đăng nhập hay không.
  Future<void> boot() async {
    final started = DateTime.now();
    await api.loadTokens();
    var next = AuthStatus.loggedOut;
    if (api.hasToken) {
      try {
        await store.refresh(force: true);
        next = AuthStatus.loggedIn;
      } on ApiException catch (e) {
        // Mất mạng nhưng vẫn còn token -> cho vào app, store tự thử lại; 401 -> về đăng nhập.
        if (e.isNetwork) next = AuthStatus.loggedIn;
      }
    }
    final wait = const Duration(milliseconds: 1200) - DateTime.now().difference(started);
    if (!wait.isNegative) await Future.delayed(wait);
    _enter(next);
  }

  Future<void> login(String identifier, String password) async {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;   // dart:io Platform không chạy trên web
    final d = await api.request('POST', Endpoints.login,
        body: {
          'identifier': identifier,
          'password': password,
          'client': 'app',
          'platform': isIos ? 'ios' : 'android',
          'device_name': kIsWeb ? 'Trình duyệt web' : (isIos ? 'iPhone' : 'Android'),
        },
        auth: false);
    if (d['two_factor_required'] == true) {
      _challenge = d['challenge_token'] as String?;
      final m = (d['methods'] ?? d['two_factor_methods']);
      twoFaMethods = m is List && m.isNotEmpty ? m.map((e) => '$e').toList() : const ['totp'];
      twoFaMethod = twoFaMethods.first;
      status = AuthStatus.needTwoFa;
      notifyListeners();
      return;
    }
    await _finish(d);
  }

  Future<void> verifyTwoFa(String code) async {
    final d = await api.request('POST', Endpoints.twoFaVerify,
        body: {'challenge_token': _challenge, 'method': twoFaMethod, 'code': code}, auth: false);
    await _finish(d);
  }

  /// Gửi mã 2FA qua email (khi chọn phương thức email).
  Future<void> sendEmailCode() async {
    final d = await api.request('POST', Endpoints.twoFaEmailSend, body: {'challenge_token': _challenge}, auth: false);
    maskedEmail = d['masked_email'] as String?;
    twoFaMethod = 'email';
    notifyListeners();
  }

  Future<void> _finish(Map<String, dynamic> d) async {
    final access = d['access_token'];
    if (access is! String) {
      throw ApiException('Máy chủ không trả access_token (kiểm tra tham số client).', code: 'NO_TOKEN');
    }
    await api.saveTokens(access, d['refresh_token'] as String?);
    _challenge = null;
    await store.refresh(force: true).catchError((_) {});
    _enter(AuthStatus.loggedIn);
  }

  /// Đăng ký: server gửi email xác thực, chưa đăng nhập ngay.
  Future<String> register({required String email, required String username, required String password, String fullName = ''}) async {
    final d = await api.request('POST', Endpoints.register,
        body: {'email': email, 'username': username, 'password': password, 'full_name': fullName}, auth: false);
    return '${d['message'] ?? 'Đã gửi email xác thực. Hãy kiểm tra hộp thư.'}';
  }

  Future<String> forgotPassword(String email) async {
    final d = await api.request('POST', Endpoints.passwordReset, body: {'email': email}, auth: false);
    return '${d['message'] ?? 'Nếu email tồn tại, hướng dẫn đặt lại mật khẩu đã được gửi.'}';
  }

  void _enter(AuthStatus s) {
    status = s;
    s == AuthStatus.loggedIn ? store.startPolling() : store.stopPolling();
    if (s == AuthStatus.loggedIn) push.register();
    notifyListeners();
  }

  void backToLogin() {
    _challenge = null;
    _enter(AuthStatus.loggedOut);
  }

  /// Token hết hạn hẳn (refresh thất bại).
  void sessionExpired() {
    store.clear();
    backToLogin();
  }

  Future<void> logout() async {
    await push.unregister();
    try {
      await api.request('POST', Endpoints.logout, body: {});
    } catch (_) {}
    await api.clearTokens();
    store.clear();
    backToLogin();
  }
}

final auth = AuthState();
