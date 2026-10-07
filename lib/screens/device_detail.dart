import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/toast.dart';
import '../widgets/ui.dart';
import 'account_dialogs.dart';

class DeviceDetailScreen extends StatelessWidget {
  final String id;
  const DeviceDetailScreen({super.key, required this.id});

  Future<void> _run(Future<void> Function() f) async {
    try {
      await f();
    } on ApiException catch (e) {
      toast(e.message);
    }
  }

  Future<void> _set(Device d, String key, bool v) => _run(() => store.updateDevice(d.id, {key: v}));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (ctx, _) {
                if (store.devices.isEmpty) return const Center(child: CircularProgressIndicator());
                final d = store.devices.firstWhere((x) => x.id == id, orElse: () => store.devices.first);
                final (c, _, label) = lockMeta(d.lock);
                final can = d.online && !d.busy;
                final evs = store.events.take(5).toList();
                return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
                  Row(children: [
                    RoundBtn(Icons.arrow_back_rounded, onTap: () => context.pop()),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.name, style: t(22, w: FontWeight.w800, ls: -.5)),
                        Text(d.code, style: t(12.5, color: C.sub)),
                      ]),
                    ),
                    Pill(d.online ? 'Online' : 'Mất kết nối', d.online ? C.green : C.red),
                  ]),
                  const SizedBox(height: 20),
                  Center(child: LockOrb(d: d, size: 190, onTap: () => toggleLock(context, d))),
                  const SizedBox(height: 4),
                  Center(child: Text(d.busy ? 'Đang gửi lệnh…' : label, style: t(28, w: FontWeight.w800, ls: -.8, color: c))),
                  const SizedBox(height: 26),
                  Row(children: [
                    Expanded(
                        child: GradBtn('Khóa', icon: Icons.lock_rounded, filled: false,
                            onTap: can && d.canLock ? () => store.send(d, 'LOCK') : null)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GradBtn('Mở khóa', icon: Icons.lock_open_rounded,
                            onTap: can && d.canUnlock ? () => store.send(d, 'UNLOCK') : null)),
                  ]),
                  if (!d.online)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Center(child: Text('Thiết bị mất kết nối nên chưa gửi lệnh được.', style: t(13, color: C.red))),
                    ),
                  const SizedBox(height: 22),
                  Row(children: [
                    MiniStat(Icons.battery_5_bar_rounded, 'Pin', '${d.battery}%',
                        d.battery < 20 ? C.red : d.battery < 50 ? C.amber : C.green),
                    const SizedBox(width: 10),
                    MiniStat(Icons.shield_rounded, 'Phá khóa', d.tamper ? 'CÓ' : 'Không', d.tamper ? C.red : C.cyan),
                    const SizedBox(width: 10),
                    MiniStat(Icons.timer_outlined, 'Khóa tạm', d.lockedOut ? 'ĐANG' : 'Không', d.lockedOut ? C.red : C.cyan),
                  ]),
                  if (d.isOwner) ...[
                    const Section('Cài đặt khóa'),
                    Glass(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        ListTile(
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(d.name, style: t(14.5, w: FontWeight.w600)),
                          subtitle: Text(d.location.isEmpty ? 'Chưa đặt vị trí' : d.location, style: t(12.5, color: C.sub)),
                          onTap: () => showForm(context,
                              title: 'Tên và vị trí',
                              action: 'Lưu',
                              initial: [d.name, d.location],
                              fields: [('Tên khóa', false, null), ('Vị trí', false, null)],
                              submit: (v) async {
                                await store.updateDevice(d.id, {'name': v[0], 'location': v[1]});
                                return 'Đã lưu.';
                              }),
                        ),
                        SwitchListTile(
                            secondary: const Icon(Icons.wifi_rounded), title: const Text('Wi-Fi'), value: d.wifi,
                            onChanged: (v) => _set(d, 'wifi_enabled', v)),
                        SwitchListTile(
                            secondary: const Icon(Icons.bluetooth_rounded), title: const Text('Bluetooth'), value: d.bluetooth,
                            onChanged: (v) => _set(d, 'bluetooth_enabled', v)),
                        SwitchListTile(
                            secondary: const Icon(Icons.nfc_rounded), title: const Text('NFC'), value: d.nfc,
                            onChanged: (v) => _set(d, 'nfc_enabled', v)),
                        ListTile(
                          leading: const Icon(Icons.restart_alt_rounded, color: C.red),
                          title: Text('Khởi động lại khóa', style: t(14.5, w: FontWeight.w600, color: C.red)),
                          subtitle: Text(d.firmware.isEmpty ? '' : 'Firmware ${d.firmware}', style: t(12.5, color: C.sub)),
                          enabled: d.online,
                          onTap: () => _run(() => store.reboot(d)),
                        ),
                      ]),
                    ),
                  ],
                  const Section('Lượt mở cửa gần đây'),
                  for (int i = 0; i < evs.length; i++) EventRow(evs[i], last: i == evs.length - 1),
                ]);
              },
            ),
          ),
        ),
      );
}
