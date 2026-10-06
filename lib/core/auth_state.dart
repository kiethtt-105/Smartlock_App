import 'package:flutter/foundation.dart';

enum AuthStatus { unknown, loggedOut, needTwoFa, loggedIn }

class AuthState extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;

  /// Splash: giả lập kiểm tra token đã lưu
  Future<void> boot() async {
    await Future.delayed(const Duration(seconds: 2));
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

  void login(String email, String password) {
    status = AuthStatus.needTwoFa; // giả lập: tài khoản nào cũng yêu cầu 2FA
    notifyListeners();
  }

  void verifyTwoFa(String code) {
    status = AuthStatus.loggedIn;
    notifyListeners();
  }

  void backToLogin() {
    status = AuthStatus.loggedOut;
    notifyListeners();
  }

  void logout() => backToLogin();
}

final auth = AuthState();
