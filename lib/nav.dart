import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'state/app_state.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Có token đã lưu thì vào thẳng app, không thì qua đăng nhập.
/// Lỗi khi đọc phiên (secure storage hỏng, ...) -> về đăng nhập, không để Splash treo.
Future<Widget> resolveHome() async {
  try {
    final hasSession = await AppState.instance.restore();
    return hasSession ? const MainScreen() : const LoginScreen();
  } catch (e, s) {
    debugPrint('resolveHome lỗi: $e\n$s');
    return const LoginScreen();
  }
}

bool _leaving = false;

/// Xóa phiên rồi về màn hình đăng nhập. Nhiều request cùng trả 401 chỉ chạy một lần.
Future<void> goToLogin() async {
  if (_leaving) return;
  _leaving = true;
  try {
    // Chờ xóa xong (clear() có thể đồng bộ hoặc async) rồi mới điều hướng.
    await Future<void>.sync(() => AppState.instance.clear());
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  } finally {
    _leaving = false;
  }
}

Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));