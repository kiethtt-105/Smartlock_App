import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../nav.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';
import 'device_pages.dart';

class LockSettingsScreen extends StatefulWidget {
  final LockDevice device;

  const LockSettingsScreen({super.key, required this.device});

  @override
  State<LockSettingsScreen> createState() => _LockSettingsScreenState();
}

class _LockSettingsScreenState extends State<LockSettingsScreen> {
  late LockDevice _dev = widget.device;
  bool _busy = false;

  Future<void> _reload() async {
    try {
      final d = await SmartlockApi.device(_dev.id);
      if (mounted) setState(() => _dev = d);
    } catch (_) {}
  }

  Future<void> _open(Widget page) async {
    await pushPage(context, page);
    _reload();
  }

  Future<void> _reboot() async {
    if (!await confirmDialog(context,
        title: 'Khởi động lại khóa?', text: 'Khóa sẽ mất kết nối vài giây.', okText: 'Khởi động lại')) {
      return;
    }
    try {
      await SmartlockApi.sendCommand(_dev.id, 'REBOOT');
      if (mounted) showMsg(context, 'Đã gửi lệnh khởi động lại.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _clearLockout() async {
    try {
      await SmartlockApi.clearLockout(_dev.id);
      if (mounted) showMsg(context, 'Đã gỡ khóa tạm.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      if (_dev.isOwner) {
        final code = await promptDialog(context,
            title: 'Gỡ khóa khỏi tài khoản',
            hint: 'Nhập lại mã khóa ${_dev.deviceCode}',
            okText: 'Gỡ khóa');
        if (code == null || code.isEmpty) return;
        await SmartlockApi.releaseDevice(_dev.id, code);
        if (mounted) showMsg(context, 'Đã gỡ khóa khỏi tài khoản.');
      } else {
        if (!await confirmDialog(context,
            title: 'Rời khỏi khóa?',
            text: 'Bạn sẽ không còn quyền dùng khóa này.',
            okText: 'Rời khỏi',
            danger: true)) {
          return;
        }
        final shares = await SmartlockApi.incomingShares();
        final mine = shares.where((s) => s.deviceId == _dev.id).toList();
        if (mine.isEmpty) throw ApiException('NOT_FOUND', 'Không tìm thấy quyền chia sẻ.', 404);
        await SmartlockApi.leaveShare(mine.first.id);
      }
      await AppState.instance.refreshDevices(silent: true);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
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
                SettingRow(
                    title: 'Những điều cơ bản',
                    onTap: () => _open(DeviceBasicsScreen(device: _dev))),
              ]),
              const SizedBox(height: 12),
              SettingGroup(children: [
                SettingRow(
                    title: 'Gateway', onTap: () => _open(DeviceGatewayScreen(device: _dev))),
              ]),
              const SizedBox(height: 12),
              SettingGroup(children: [
                SettingRow(title: 'Thời gian', onTap: () => _open(DeviceTimeScreen(device: _dev))),
                if (_dev.isOwner) SettingRow(title: 'Khởi động lại khóa', onTap: _reboot),
                if (_dev.isOwner) SettingRow(title: 'Gỡ khóa tạm (nhập sai nhiều)', onTap: _clearLockout),
              ]),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DangerButton(
                  text: _dev.isOwner ? 'Xóa' : 'Rời khỏi khóa',
                  onPressed: _busy ? () {} : _delete,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _dev.isOwner
                    ? 'Xóa sẽ gỡ khóa khỏi tài khoản và thu hồi mọi thẻ, PIN, khuôn mặt, quyền chia sẻ.'
                    : 'Bạn đang dùng khóa này do ${_dev.ownerName} chia sẻ.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
