import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';
import '../widgets/paged_list.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _key = GlobalKey<PagedListState<NotificationInfo>>();

  Color _color(String sev) => switch (sev) {
        'critical' => AppColors.red,
        'warning' => const Color(0xFFFFB020),
        _ => AppColors.blue,
      };

  Future<void> _readAll() async {
    try {
      await SmartlockApi.markAllRead();
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _clearRead() async {
    if (!await confirmDialog(context,
        title: 'Xóa thông báo đã đọc?', okText: 'Xóa', danger: true)) {
      return;
    }
    try {
      await SmartlockApi.clearReadNotifications();
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TitleBar(
              title: 'Thông báo',
              onBack: () => Navigator.pop(context),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (v) => v == 'read' ? _readAll() : _clearRead(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'read', child: Text('Đánh dấu đã đọc hết')),
                  PopupMenuItem(value: 'clear', child: Text('Xóa thông báo đã đọc')),
                ],
              ),
            ),
            Expanded(
              child: PagedList<NotificationInfo>(
                key: _key,
                fetch: (p) => SmartlockApi.notifications(page: p),
                emptyText: 'Chưa có thông báo.',
                itemBuilder: (context, n, reload) => Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: AppColors.red, borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    _key.currentState?.removeWhere((x) => x.id == n.id);
                    SmartlockApi.deleteNotification(n.id).catchError((_) {});
                  },
                  child: ListCard(
                    leading: iconBadge(
                        n.isRead ? Icons.notifications_none : Icons.notifications_active,
                        color: _color(n.severity)),
                    title: n.title,
                    subtitle: '${n.message}\n${fmtTime(n.createdAt)}',
                    trailing: n.isRead
                        ? null
                        : Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: AppColors.blue),
                          ),
                    onTap: n.isRead
                        ? null
                        : () async {
                            await SmartlockApi.markRead(n.id).catchError((_) {});
                            reload();
                          },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
