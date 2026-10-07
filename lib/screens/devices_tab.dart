import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'account_dialogs.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (ctx, _) {
            final online = store.devices.where((d) => d.online).length;
            return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 130), children: [
              Reveal(index: 0, child: Text('Thiết bị', style: t(32, w: FontWeight.w800, ls: -1))),
              const SizedBox(height: 4),
              Reveal(index: 0, child: Text('${store.devices.length} khóa · $online đang online', style: t(14, color: C.sub))),
              const SizedBox(height: 22),
              for (int i = 0; i < store.devices.length; i++)
                Reveal(index: i + 1, child: Padding(padding: const EdgeInsets.only(bottom: 14), child: _Card(store.devices[i]))),
              Reveal(
                index: 5,
                child: Tap(
                  onTap: () => showClaimDevice(context),
                  child: Container(
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22), border: Border.all(color: C.violet.withValues(alpha: .5), width: 1.4)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_rounded, color: C.violet),
                      const SizedBox(width: 8),
                      Text('Thêm thiết bị', style: t(15, w: FontWeight.w700, color: C.violet)),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        ),
      );
}

class _Card extends StatelessWidget {
  final Device d;
  const _Card(this.d);

  @override
  Widget build(BuildContext context) {
    final (c, icon, label) = lockMeta(d.lock);
    return Glass(
      tint: c,
      onTap: () => context.push('/device/${d.id}'),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .15), border: Border.all(color: c.withValues(alpha: .4))),
          child: Icon(d.busy ? Icons.sync_rounded : icon, color: c, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: t(17, w: FontWeight.w700, ls: -.3)),
            const SizedBox(height: 2),
            Text(d.code, style: t(12.5, color: C.sub)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Pill(d.online ? 'Online' : 'Mất kết nối', d.online ? C.green : C.red),
              Pill('${d.battery}%', d.battery < 20 ? C.red : C.sub, icon: Icons.battery_5_bar_rounded),
              if (d.tamper) const Pill('Phá khóa', C.red, icon: Icons.warning_rounded),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(label, style: t(13, w: FontWeight.w700, color: c)),
          const SizedBox(height: 18),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: C.sub),
        ]),
      ]),
    );
  }
}
