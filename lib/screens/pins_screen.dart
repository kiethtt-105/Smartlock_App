import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/async_page.dart';
import '../widgets/helpers.dart';

class PinsScreen extends StatelessWidget {
  final LockDevice device;

  const PinsScreen({super.key, required this.device});

  Future<void> _create(BuildContext context, Future<void> Function() reload) async {
    final label = TextEditingController();
    var ttl = 1440;
    var uses = 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Tạo mã PIN cho khách'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'Tên khách / ghi chú')),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: ttl,
                decoration: const InputDecoration(labelText: 'Hết hạn sau'),
                items: const [
                  DropdownMenuItem(value: 60, child: Text('1 giờ')),
                  DropdownMenuItem(value: 1440, child: Text('1 ngày')),
                  DropdownMenuItem(value: 10080, child: Text('7 ngày')),
                  DropdownMenuItem(value: 43200, child: Text('30 ngày')),
                ],
                onChanged: (v) => setS(() => ttl = v ?? ttl),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: uses,
                decoration: const InputDecoration(labelText: 'Số lần dùng'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('1 lần')),
                  DropdownMenuItem(value: 5, child: Text('5 lần')),
                  DropdownMenuItem(value: 0, child: Text('Không giới hạn')),
                ],
                onChanged: (v) => setS(() => uses = v ?? uses),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tạo', style: TextStyle(color: AppColors.blue)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final (_, plain) = await SmartlockApi.createPin(device.id,
          label: label.text.trim(), ttlMinutes: ttl, maxUses: uses);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mã PIN đã tạo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(plain,
                  style: const TextStyle(
                      fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: 6)),
              const SizedBox(height: 12),
              const Text('Mã này chỉ hiển thị MỘT lần. Hãy gửi cho khách ngay.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: plain)),
              child: const Text('Sao chép'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xong')),
          ],
        ),
      );
      await reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<List<DoorPin>>(
      title: 'Mã PIN khách',
      load: () => SmartlockApi.pins(device.id),
      fab: (ctx, reload) => appFab('Tạo mã PIN', Icons.add, () => _create(ctx, reload)),
      builder: (ctx, pins, reload) {
        if (pins.isEmpty) {
          return ListView(children: [
            SizedBox(height: 120, child: emptyView('Chưa có mã PIN nào.', icon: Icons.pin_outlined)),
          ]);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          itemCount: pins.length,
          itemBuilder: (_, i) {
            final p = pins[i];
            final color = p.isRevoked
                ? AppColors.textSecondary
                : (p.isValidNow ? AppColors.green : AppColors.red);
            final status = p.isRevoked ? 'Đã thu hồi' : (p.isValidNow ? 'Đang hiệu lực' : 'Hết hạn');
            return ListCard(
              leading: iconBadge(Icons.pin_outlined, color: color),
              title: p.label.isEmpty ? 'Mã PIN không tên' : p.label,
              subtitle:
                  '$status · hết hạn ${fmtTime(p.expiresAt)}\nĐã dùng ${p.useCount}${(p.maxUses ?? 0) > 0 ? '/${p.maxUses}' : ''} lần${p.createdBy.isNotEmpty ? ' · tạo bởi ${p.createdBy}' : ''}',
              trailing: p.isRevoked
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.block, color: AppColors.red),
                      tooltip: 'Thu hồi',
                      onPressed: () async {
                        if (!await confirmDialog(ctx,
                            title: 'Thu hồi mã PIN?', okText: 'Thu hồi', danger: true)) {
                          return;
                        }
                        try {
                          await SmartlockApi.revokePin(p.id);
                          await reload();
                        } catch (e) {
                          if (ctx.mounted) showError(ctx, e);
                        }
                      },
                    ),
            );
          },
        );
      },
    );
  }
}
