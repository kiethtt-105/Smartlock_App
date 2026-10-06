import 'package:flutter/material.dart';
import '../core/mock_data.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  bool unreadOnly = false;

  void _sync() => unreadCount.value = mockNotes.where((n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    final list = mockNotes.where((n) => !unreadOnly || !n.read).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo'), actions: [
        TextButton(
          onPressed: () => setState(() {
            for (final n in mockNotes) { n.read = true; }
            _sync();
          }),
          child: const Text('Đọc hết'),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            ChoiceChip(label: const Text('Tất cả'), selected: !unreadOnly, onSelected: (_) => setState(() => unreadOnly = false)),
            const SizedBox(width: 8),
            ChoiceChip(
                label: Text('Chưa đọc (${mockNotes.where((n) => !n.read).length})'),
                selected: unreadOnly,
                onSelected: (_) => setState(() => unreadOnly = true)),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(Icons.notifications_off_outlined, 'Không có thông báo', sub: 'Bạn đã đọc hết rồi.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => NoteTile(list[i], onTap: () => setState(() {
                        list[i].read = true;
                        _sync();
                      })),
                ),
        ),
      ]),
    );
  }
}