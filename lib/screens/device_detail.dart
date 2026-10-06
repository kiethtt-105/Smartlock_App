import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class DeviceDetailScreen extends StatelessWidget {
  final String id;
  const DeviceDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (ctx, _) {
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
                            onTap: can ? () => store.send(d, 'LOCK') : null)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GradBtn('Mở khóa', icon: Icons.lock_open_rounded,
                            onTap: can ? () => store.send(d, 'UNLOCK') : null)),
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
                  const Section('Lượt mở cửa gần đây'),
                  for (int i = 0; i < evs.length; i++) EventRow(evs[i], last: i == evs.length - 1),
                ]);
              },
            ),
          ),
        ),
      );
}
