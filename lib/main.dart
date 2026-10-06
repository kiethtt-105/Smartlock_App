import 'package:flutter/material.dart';
import 'core/auth_state.dart';
import 'core/config_service.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.load();
  auth.boot(); // splash giả lập 2 giây
  runApp(const SmartlockApp());
}

class SmartlockApp extends StatelessWidget {
  const SmartlockApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Smartlock',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
      );
}
