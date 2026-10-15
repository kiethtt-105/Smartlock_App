import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    AppState.instance.refreshUser().catchError((_) {});
  }

  Future<void> _edit({required bool name}) async {
    final u = AppState.instance.user;
    final v = await promptDialog(context,
        title: name ? 'Họ và tên' : 'Số điện thoại',
        initial: name ? (u?.fullName ?? '') : (u?.phone ?? ''),
        keyboard: name ? null : TextInputType.phone);
    if (v == null) return;
    try {
      await SmartlockApi.updateProfile(fullName: name ? v : null, phone: name ? null : v);
      await AppState.instance.refreshUser();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _changePassword() async {
    final oldPw = TextEditingController();
    final newPw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: oldPw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại')),
            TextField(
                controller: newPw,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu mới')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đổi', style: TextStyle(color: AppColors.blue)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SmartlockApi.changePassword(oldPw.text, newPw.text);
      if (mounted) showMsg(context, 'Đã đổi mật khẩu.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _revokeOthers() async {
    if (!await confirmDialog(context,
        title: 'Đăng xuất các thiết bị khác?', okText: 'Đăng xuất', danger: true)) {
      return;
    }
    try {
      await SmartlockApi.revokeOtherSessions();
      if (mounted) showMsg(context, 'Đã đăng xuất các thiết bị khác.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final u = AppState.instance.user;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  TitleBar(title: 'Thông tin tài khoản', onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 16),
                  SettingGroup(children: [
                    SettingRow(
                        title: 'Họ và tên',
                        value: (u?.fullName.isEmpty ?? true) ? 'Chưa đặt' : u!.fullName,
                        onTap: () => _edit(name: true)),
                    SettingRow(
                        title: 'Số điện thoại',
                        value: (u?.phone.isEmpty ?? true) ? 'Chưa đặt' : u!.phone,
                        onTap: () => _edit(name: false)),
                  ]),
                  const SizedBox(height: 12),
                  SettingGroup(children: [
                    SettingRow(title: 'Email', value: u?.email ?? '', showChevron: false),
                    SettingRow(title: 'Tên đăng nhập', value: u?.username ?? '', showChevron: false),
                    SettingRow(
                        title: 'Xác thực 2 lớp',
                        value: (u?.twoFa ?? false) ? 'Đang bật' : 'Đang tắt',
                        showChevron: false),
                  ]),
                  const SizedBox(height: 12),
                  SettingGroup(children: [
                    SettingRow(title: 'Đổi mật khẩu', onTap: _changePassword),
                    SettingRow(title: 'Đăng xuất các thiết bị khác', onTap: _revokeOthers),
                  ]),
                  const SizedBox(height: 12),
                  const Text(
                    'Bật/tắt xác thực 2 lớp (Google Authenticator, Email OTP) thực hiện trên trang web.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
