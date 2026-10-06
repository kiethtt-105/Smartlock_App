import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  String _greet() {
    final h = DateTime.now().hour;
    return h < 11 ? 'Chào buổi sáng,' : h < 18 ? 'Chào buổi chiều,' : 'Chào buổi tối,';
  }

  String _hint(Device d) => d.busy
      ? 'Đang gửi lệnh…'
      : !d.online ? 'Thiết bị mất kết nối' : d.lock == 'locked' ? 'Chạm để mở khóa' : 'Chạm để khóa';

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (ctx, _) {
            final d = store.devices[_page];
            final (c, _, label) = lockMeta(d.lock);
            final evs = store.events.take(4).toList();
            return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 130), children: [
              Reveal(
                index: 0,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greet(), style: t(13.5, color: C.sub)),
                      const SizedBox(height: 2),
                      Text('Nguyễn Văn A', style: t(24, w: FontWeight.w800, ls: -.6)),
                    ]),
                  ),
                  RoundBtn(Icons.notifications_none_rounded,
                      badge: store.unread, onTap: () => context.push('/notifications')),
                ]),
              ),
              const SizedBox(height: 10),
              Reveal(
                index: 1,
                child: SizedBox(
                  height: 360,
                  child: PageView.builder(
                    controller: _pc,
                    itemCount: store.devices.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) {
                      final dv = store.devices[i];
                      final (dc, _, dl) = lockMeta(dv.lock);
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        LockOrb(d: dv, size: 190, onTap: () => toggleLock(context, dv)),
                        const SizedBox(height: 6),
                        Text(dv.name, style: t(22, w: FontWeight.w800, ls: -.5)),
                        const SizedBox(height: 4),
                        Text(dl, style: t(15, w: FontWeight.w700, color: dc)),
                      ]);
                    },
                  ),
                ),
              ),
              Center(child: Text(_hint(d), style: t(13, color: C.sub))),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < store.devices.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 24 : 7, height: 7,
                    decoration: BoxDecoration(
                        color: i == _page ? c : C.card2, borderRadius: BorderRadius.circular(9)),
                  ),
              ]),
              const SizedBox(height: 24),
              Reveal(
                index: 2,
                child: Row(children: [
                  MiniStat(Icons.battery_5_bar_rounded, 'Pin', '${d.battery}%',
                      d.battery < 20 ? C.red : d.battery < 50 ? C.amber : C.green),
                  const SizedBox(width: 10),
                  MiniStat(Icons.wifi_rounded, 'Kết nối', d.online ? 'Online' : 'Mất', d.online ? C.green : C.red),
                  const SizedBox(width: 10),
                  MiniStat(Icons.shield_rounded, 'Phá khóa', d.tamper ? 'CÓ' : 'Không', d.tamper ? C.red : C.cyan),
                ]),
              ),
              Section('Hoạt động gần đây', action: 'Xem hết', onAction: () => context.go('/access')),
              for (int i = 0; i < evs.length; i++)
                Reveal(index: 3 + i, child: EventRow(evs[i], last: i == evs.length - 1)),
            ]);
          },
        ),
      );
}
