import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/auth_state.dart';
import 'screens/access_tab.dart';
import 'screens/auth_screens.dart';
import 'screens/device_detail.dart';
import 'screens/devices_tab.dart';
import 'screens/home_tab.dart';
import 'screens/main_shell.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_tab.dart';

const _authPaths = {'/splash', '/login', '/2fa'};

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
    switch (auth.status) {
      case AuthStatus.unknown:
        return loc == '/splash' ? null : '/splash';
      case AuthStatus.loggedOut:
        return loc == '/login' ? null : '/login';
      case AuthStatus.needTwoFa:
        return loc == '/2fa' ? null : '/2fa';
      case AuthStatus.loggedIn:
        return _authPaths.contains(loc) ? '/home' : null;
    }
  },
  routes: [
    GoRoute(path: '/splash', pageBuilder: (c, s) => _page(s, const SplashScreen())),
    GoRoute(path: '/login', pageBuilder: (c, s) => _page(s, const LoginScreen())),
    GoRoute(path: '/2fa', pageBuilder: (c, s) => _page(s, const TwoFaScreen())),
    GoRoute(path: '/notifications', pageBuilder: (c, s) => _page(s, const NotificationsScreen())),
    GoRoute(
      path: '/device/:id',
      pageBuilder: (c, s) => _page(s, DeviceDetailScreen(id: s.pathParameters['id']!)),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => MainShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/devices', builder: (_, __) => const DevicesTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/access', builder: (_, __) => const AccessTab())]),
        StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileTab())]),
      ],
    ),
  ],
);
