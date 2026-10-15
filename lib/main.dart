import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'nav.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  // Bắt cả lỗi framework lẫn lỗi async không được xử lý.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // App tự vẽ thanh tiêu đề (không dùng AppBar) nên phải đặt ở đây:
    // nền tối -> icon thanh trạng thái màu sáng.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };

    // Phiên bị thu hồi / hết hạn -> về đăng nhập (có chốt chặn nhiều 401 cùng lúc).
    ApiClient.instance.onSessionLost = goToLogin;

    runApp(const SmartlockApp());
  }, (error, stack) => debugPrint('Uncaught: $error\n$stack'));
}

class SmartlockApp extends StatelessWidget {
  const SmartlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smartlock',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: const SplashScreen(),
    );
  }
}