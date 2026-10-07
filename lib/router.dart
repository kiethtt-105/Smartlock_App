import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/auth_state.dart';
import 'screens/face_enroll_screen.dart';
import 'screens/history_screen.dart';
import 'screens/link_screens.dart';
import 'screens/live_screen.dart';
import 'screens/nfc_screen.dart';
import 'screens/share_form_screen.dart';
import 'core/store.dart' show ShareItem;
import 'screens/access_screens.dart';
import 'screens/access_tab.dart';
import 'screens/auth_screens.dart';
import 'screens/device_detail.dart';
import 'screens/devices_tab.dart';
import 'screens/form_pages.dart';
import 'screens/home_tab.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_tab.dart';

const _authPaths = {'/splash', '/login', '/2fa', '/register', '/forgot'};
const _publicPaths = {'/login', '/register', '/forgot'};   // đăng xuất rồi vẫn vào được

/// Link từ email (xác thực email / đặt lại mật khẩu): mở được ở mọi trạng thái đăng nhập.
bool _isLink(String loc) => loc.startsWith('/verify-email/') || loc.startsWith('/reset-password/');

CustomTransitionPage<void> _page(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (ctx, anim, sec, c) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero).animate(curved), child: c),
        );
      },
    );

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: auth,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (_isLink(loc)) return null;
    switch (auth.status) {
      case AuthStatus.unknown:
        return loc == '/splash' ? null : '/splash';
      case AuthStatus.loggedOut:
        return _publicPaths.contains(loc) ? null : '/login';
      case AuthStatus.needTwoFa:
        return loc == '/2fa' ? null : '/2fa';
      case AuthStatus.loggedIn:
        return _authPaths.contains(loc) ? '/home' : null;
    }
  },
  routes: [
    GoRoute(path: '/splash', pageBuilder: (c, s) => _page(s, const SplashScreen())),
    GoRoute(path: '/login', pageBuilder: (c, s) => _page(s, const LoginScreen())),
    GoRoute(path: '/register', pageBuilder: (c, s) => _page(s, const RegisterScreen())),
    GoRoute(path: '/forgot', pageBuilder: (c, s) => _page(s, const ForgotPasswordScreen())),
    GoRoute(path: '/2fa', pageBuilder: (c, s) => _page(s, const TwoFaScreen())),
    GoRoute(path: '/access/pins', pageBuilder: (c, s) => _page(s, const PinsScreen())),
    GoRoute(path: '/access/cards', pageBuilder: (c, s) => _page(s, const CardsScreen())),
    GoRoute(path: '/access/faces', pageBuilder: (c, s) => _page(s, const FacesScreen())),
    GoRoute(path: '/access/shares', pageBuilder: (c, s) => _page(s, const SharesScreen())),
    GoRoute(
      path: '/verify-email/:token',
      pageBuilder: (c, s) => _page(s, VerifyEmailScreen(token: s.pathParameters['token']!)),
    ),
    GoRoute(
      path: '/reset-password/:uid/:token',
      pageBuilder: (c, s) =>
          _page(s, ResetPasswordScreen(uid: s.pathParameters['uid']!, token: s.pathParameters['token']!)),
    ),
    GoRoute(
      path: '/history',
      pageBuilder: (c, s) => _page(s, HistoryScreen(deviceId: s.uri.queryParameters['device'])),
    ),
    GoRoute(path: '/device/:id/live', pageBuilder: (c, s) => _page(s, LiveScreen(id: s.pathParameters['id']!))),
    GoRoute(path: '/device/:id/face', pageBuilder: (c, s) => _page(s, FaceEnrollScreen(deviceId: s.pathParameters['id']!))),
    GoRoute(path: '/device/:id/nfc', pageBuilder: (c, s) => _page(s, NfcScreen(deviceId: s.pathParameters['id']!))),
    GoRoute(
      path: '/device/:id/share',
      pageBuilder: (c, s) =>
          _page(s, ShareFormScreen(deviceId: s.pathParameters['id']!, edit: s.extra is ShareItem ? s.extra as ShareItem : null)),
    ),
    GoRoute(path: '/notifications', pageBuilder: (c, s) => _page(s, const NotificationsScreen())),
    GoRoute(
      path: '/device/:id',
      pageBuilder: (c, s) => _page(s, DeviceDetailScreen(id: s.pathParameters['id']!)),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/devices', builder: (_, _) => const DevicesTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/access', builder: (_, _) => const AccessTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileTab())]),
      ],
    ),
  ],
);
