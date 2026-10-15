import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../state/app_state.dart';
import '../state/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';
import 'login_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _sound = true;
  bool _tapToUnlock = true;
  bool _push = true;
  bool _personalized = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final s = await AppPrefs.getBool(AppPrefs.sound);
    final t = await AppPrefs.getBool(AppPrefs.tapToUnlock);
    final p = await AppPrefs.getBool(AppPrefs.personalized);
    final push = await AppPrefs.getBool('push_enabled');
    if (mounted) {
      setState(() {
        _sound = s;
        _tapToUnlock = t;
        _personalized = p;
        _push = push;
      });
    }
  }

  Future<void> _setPush(bool v) async {
    setState(() => _push = v);
    await AppPrefs.setBool('push_enabled', v);
    try {
      await SmartlockApi.setPush(v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _push = !v);
      await AppPrefs.setBool('push_enabled', !v);
      showError(context, e);
    }
  }

  Future<void> _logout() async {
    if (!await confirmDialog(context, title: 'Đăng xuất?', okText: 'Đăng xuất', danger: true)) {
      return;
    }
    await AppState.instance.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final pw = await promptDialog(context,
        title: 'Xóa tài khoản',
        hint: 'Nhập mật khẩu để xác nhận',
        obscure: true,
        okText: 'Xóa tài khoản');
    if (pw == null || pw.isEmpty) return;
    try {
      await SmartlockApi.deleteAccount(pw);
      await AppState.instance.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              TitleBar(title: 'Cài đặt', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              SettingGroup(children: [
                SettingSwitchRow(
                    title: 'Âm thanh',
                    value: _sound,
                    onChanged: (v) {
                      setState(() => _sound = v);
                      AppPrefs.setBool(AppPrefs.sound, v);
                    }),
                SettingSwitchRow(
                    title: 'Chạm để mở khóa',
                    value: _tapToUnlock,
                    onChanged: (v) {
                      setState(() => _tapToUnlock = v);
                      AppPrefs.setBool(AppPrefs.tapToUnlock, v);
                    }),
                SettingSwitchRow(title: 'Thông báo đẩy', value: _push, onChanged: _setPush),
              ]),
              const SizedBox(height: 12),
              const SettingGroup(children: [
                SettingRow(title: 'Ngôn ngữ', value: 'Tiếng Việt', showChevron: false),
                SettingRow(title: 'Phiên bản app', value: '1.0.0', showChevron: false),
              ]),
              const SizedBox(height: 12),
              SettingGroup(children: [
                SettingSwitchRow(
                    title: 'Khuyến nghị cá nhân hóa',
                    value: _personalized,
                    onChanged: (v) {
                      setState(() => _personalized = v);
                      AppPrefs.setBool(AppPrefs.personalized, v);
                    }),
              ]),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DangerButton(text: 'Đăng xuất', onPressed: _logout),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: _deleteAccount,
                    child: const Text('Xóa tài khoản',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
