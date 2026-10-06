import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainShell({super.key, required this.shell});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Nhà'),
    (Icons.lock_outline_rounded, Icons.lock_rounded, 'Thiết bị'),
    (Icons.vpn_key_outlined, Icons.vpn_key_rounded, 'Truy cập'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Tôi'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        backgroundColor: C.bg,
        body: GlowBg(child: shell),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 12),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: C.card2.withValues(alpha: .97),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: C.stroke),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Row(children: [
              for (int i = 0; i < _items.length; i++)
                Expanded(
                  child: Tap(
                    scale: .9,
                    onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: i == shell.currentIndex ? C.violet.withValues(alpha: .2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedScale(
                          scale: i == shell.currentIndex ? 1.12 : 1,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutBack,
                          child: Icon(i == shell.currentIndex ? _items[i].$2 : _items[i].$1,
                              size: 24, color: i == shell.currentIndex ? C.violet : C.sub),
                        ),
                        const SizedBox(height: 3),
                        Text(_items[i].$3,
                            style: t(11, w: FontWeight.w600, color: i == shell.currentIndex ? C.text : C.sub)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
