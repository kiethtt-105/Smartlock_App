import 'package:flutter/material.dart';
import 'core/api_client.dart';
import 'core/auth_state.dart';
import 'core/config_service.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'core/toast.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.load();
  api.onSessionExpired = auth.sessionExpired; // refresh token hết hạn -> về màn đăng nhập
  auth.boot(); // nạp token đã lưu + gọi snapshot thật
  runApp(const SmartlockApp());
}

class SmartlockApp extends StatefulWidget {
  const SmartlockApp({super.key});

  @override
  State<SmartlockApp> createState() => _SmartlockAppState();
}

class _SmartlockAppState extends State<SmartlockApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Chạy nền thì dừng polling, quay lại thì tải ngay.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      store.resume();
    } else if (s == AppLifecycleState.paused) {
      store.pause();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Smartlock',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: messengerKey,
        theme: buildTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      );
}
