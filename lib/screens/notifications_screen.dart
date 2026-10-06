import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool unreadOnly = false;

  Widget _seg(String text, bool on, VoidCallback onTap) => Expanded(
        child: Tap(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: on ? C.violet.withValues(alpha: .28) : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: Text(text, style: t(13.5, w: FontWeight.w700, color: on ? C.text : C.sub)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (ctx, _) {
                final list = store.notes.where((n) => !unreadOnly || !n.read).toList();
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(children: [
                      RoundBtn(Icons.arrow_back_rounded, onTap: () => context.pop()),
                      const SizedBox(width: 16),
                      Expanded(child: Text('Thông báo', style: t(24, w: FontWeight.w800, ls: -.6))),
                      Tap(onTap: store.readAll, child: Text('Đọc hết', style: t(13.5, w: FontWeight.w600, color: C.violet))),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(15)),
                      child: Row(children: [
                        _seg('Tất cả', !unreadOnly, () => setState(() => unreadOnly = false)),
                        _seg('Chưa đọc (${store.unread})', unreadOnly, () => setState(() => unreadOnly = true)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: list.isEmpty
                        ? const EmptyBox(Icons.notifications_off_outlined, 'Không có thông báo', sub: 'Bạn đã đọc hết rồi.')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                            itemCount: list.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Dismissible(
                                key: ValueKey(list[i].id),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) => store.remove(list[i]),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  decoration: BoxDecoration(
                                      color: C.red.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
                                  child: const Icon(Icons.delete_outline_rounded, color: C.red),
                                ),
                                child: NoteCard(list[i], onTap: () => store.markRead(list[i])),
                              ),
                            ),
                          ),
                  ),
                ]);
              },
            ),
          ),
        ),
      );
}
