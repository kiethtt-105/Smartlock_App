import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/async_page.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';
import '../widgets/paged_list.dart';

// ───────────── Những điều cơ bản ─────────────

class DeviceBasicsScreen extends StatefulWidget {
  final LockDevice device;

  const DeviceBasicsScreen({super.key, required this.device});

  @override
  State<DeviceBasicsScreen> createState() => _DeviceBasicsScreenState();
}

class _DeviceBasicsScreenState extends State<DeviceBasicsScreen> {
  late LockDevice _d = widget.device;

  Future<void> _edit({required bool name}) async {
    final v = await promptDialog(context,
        title: name ? 'Đổi tên khóa' : 'Vị trí lắp đặt',
        initial: name ? _d.name : _d.location,
        hint: name ? 'Tên khóa' : 'VD: Cửa chính tầng 1');
    if (v == null) return;
    if (name && v.isEmpty) {
      showMsg(context, 'Tên khóa không được để trống.', error: true);
      return;
    }
    try {
      await SmartlockApi.updateDevice(_d.id, name: name ? v : null, location: name ? null : v);
      final d = await SmartlockApi.device(_d.id);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = _d.isOwner;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              TitleBar(title: 'Những điều cơ bản', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              SettingGroup(children: [
                SettingRow(
                    title: 'Tên khóa',
                    value: _d.name,
                    showChevron: owner,
                    onTap: owner ? () => _edit(name: true) : null),
                SettingRow(
                    title: 'Vị trí',
                    value: _d.location.isEmpty ? 'Chưa đặt' : _d.location,
                    showChevron: owner,
                    onTap: owner ? () => _edit(name: false) : null),
              ]),
              const SizedBox(height: 12),
              SettingGroup(children: [
                SettingRow(title: 'Mã khóa', value: _d.deviceCode, showChevron: false),
                SettingRow(
                    title: 'Địa chỉ MAC',
                    value: _d.mac.isEmpty ? '--' : _d.mac,
                    showChevron: false),
                SettingRow(
                    title: 'Phiên bản firmware',
                    value: _d.firmware.isEmpty ? '--' : _d.firmware,
                    showChevron: false),
                SettingRow(title: 'Chủ khóa', value: owner ? 'Bạn' : _d.ownerName, showChevron: false),
                SettingRow(title: 'Trạng thái', value: _d.statusDisplay, showChevron: false),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────── Gateway (kênh kết nối) ─────────────

class DeviceGatewayScreen extends StatefulWidget {
  final LockDevice device;

  const DeviceGatewayScreen({super.key, required this.device});

  @override
  State<DeviceGatewayScreen> createState() => _DeviceGatewayScreenState();
}

class _DeviceGatewayScreenState extends State<DeviceGatewayScreen> {
  late LockDevice _d = widget.device;

  Future<void> _toggle({bool? wifi, bool? bluetooth, bool? nfc}) async {
    try {
      await SmartlockApi.updateDevice(_d.id, wifi: wifi, bluetooth: bluetooth, nfc: nfc);
      final d = await SmartlockApi.device(_d.id);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = _d.isOwner;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              TitleBar(title: 'Gateway', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              SettingGroup(children: [
                SettingSwitchRow(
                    title: 'Wi-Fi (điều khiển từ xa)',
                    value: _d.wifi,
                    onChanged: (v) => owner ? _toggle(wifi: v) : null),
                SettingSwitchRow(
                    title: 'Bluetooth',
                    value: _d.bluetooth,
                    onChanged: (v) => owner ? _toggle(bluetooth: v) : null),
                SettingSwitchRow(
                    title: 'NFC',
                    value: _d.nfc,
                    onChanged: (v) => owner ? _toggle(nfc: v) : null),
              ]),
              const SizedBox(height: 12),
              Text(
                owner
                    ? 'Tắt Wi-Fi thì không mở/khóa từ xa được. Tắt NFC thì không đăng ký thẻ mới được.'
                    : 'Chỉ chủ khóa mới đổi được các kênh kết nối.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────── Thời gian (lịch sử trạng thái) ─────────────

class DeviceTimeScreen extends StatelessWidget {
  final LockDevice device;

  const DeviceTimeScreen({super.key, required this.device});

  String _state(String s) => switch (s) {
        'locked' => 'Đã khóa',
        'unlocked' => 'Đang mở',
        'jammed' => 'Kẹt',
        _ => 'Không rõ',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TitleBar(title: 'Thời gian', onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SettingGroup(children: [
                SettingRow(
                    title: 'Lần cuối kết nối',
                    value: device.lastSeen == null ? '--' : fmtTime(device.lastSeen),
                    showChevron: false),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Lịch sử trạng thái 24 giờ qua',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
            ),
            Expanded(
              child: device.can('view_history')
                  ? PagedList<StatusLogInfo>(
                      fetch: (p) => SmartlockApi.statusHistory(device.id, page: p),
                      emptyText: 'Chưa có dữ liệu trạng thái.',
                      itemBuilder: (context, l, _) => ListCard(
                        leading: iconBadge(l.lockState == 'unlocked' ? Icons.lock_open : Icons.lock_outline,
                            color: l.lockState == 'unlocked' ? AppColors.green : AppColors.blue),
                        title: _state(l.lockState),
                        subtitle:
                            '${fmtTime(l.at)}${l.battery != null ? ' · Pin ${l.battery}%' : ''}${l.tamper ? ' · Có tác động' : ''}',
                      ),
                    )
                  : emptyView('Bạn không có quyền xem lịch sử trạng thái.'),
            ),
          ],
        ),
      ),
    );
  }
}
