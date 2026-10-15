import 'package:flutter/material.dart';

import '../nav.dart';
import '../services/permission_service.dart';
import '../theme.dart';
import 'permissions_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final ok = await PermissionService.allGranted();
    // Đủ quyền thì đi tiếp (vào app nếu đã đăng nhập, không thì đăng nhập), thiếu thì xin quyền trước.
    final next = ok ? await resolveHome() : const PermissionsScreen();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE6F0FF), Color(0xFFF4F8FF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const Center(
                child: Text(
                  'SMARTLOCK',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tile(Icons.vpn_key_outlined),
                      const SizedBox(width: 24),
                      Icon(Icons.sync,
                          color: AppColors.blue.withAlpha(150), size: 28),
                      const SizedBox(width: 24),
                      _tile(Icons.lock_outline),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(IconData icon) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(icon, color: AppColors.blue, size: 40),
    );
  }
}
