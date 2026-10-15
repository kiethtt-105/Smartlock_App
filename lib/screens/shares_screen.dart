import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/async_page.dart';
import '../widgets/helpers.dart';

String _permLabel(String code) => switch (code) {
      'UNLOCK' => 'Mở khóa',
      'LOCK' => 'Khóa',
      'BLUETOOTH' => 'Bluetooth',
      'NFC_PHONE' => 'NFC điện thoại',
      'manage_nfc' => 'Thẻ NFC',
      'manage_face_profiles' => 'Khuôn mặt',
      'manage_pins' => 'Mã PIN',
      'view_history' => 'Xem lịch sử',
      _ => code,
    };

String _permText(List<String> codes) => codes.map(_permLabel).join(', ');

// ───────────── Chủ khóa: chia sẻ khóa cho người khác ─────────────

class DeviceSharesScreen extends StatelessWidget {
  final LockDevice device;

  const DeviceSharesScreen({super.key, required this.device});

  Future<void> _add(BuildContext context, Future<void> Function() reload) async {
    List<RolePreset> presets;
    try {
      presets = await SmartlockApi.presets();
    } catch (e) {
      if (context.mounted) showError(context, e);
      return;
    }
    if (presets.isEmpty || !context.mounted) return;

    final who = TextEditingController();
    var preset = presets.first.key;
    int? days;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Chia sẻ khóa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: who,
                  decoration: const InputDecoration(labelText: 'Email hoặc username người nhận'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: preset,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Vai trò'),
                  items: [
                    for (final p in presets) DropdownMenuItem(value: p.key, child: Text(p.label)),
                  ],
                  onChanged: (v) => setS(() => preset = v ?? preset),
                ),
                const SizedBox(height: 6),
                Text(presets.firstWhere((p) => p.key == preset).desc,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: days,
                  decoration: const InputDecoration(labelText: 'Thời hạn'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Vĩnh viễn')),
                    DropdownMenuItem(value: 1, child: Text('1 ngày')),
                    DropdownMenuItem(value: 7, child: Text('7 ngày')),
                    DropdownMenuItem(value: 30, child: Text('30 ngày')),
                  ],
                  onChanged: (v) => setS(() => days = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Chia sẻ', style: TextStyle(color: AppColors.blue)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (who.text.trim().isEmpty) {
      showMsg(context, 'Hãy nhập email hoặc username người nhận.', error: true);
      return;
    }
    try {
      await SmartlockApi.shareDevice(
        device.id,
        identifier: who.text.trim(),
        preset: preset,
        expiresAtIso: days == null ? null : DateTime.now().add(Duration(days: days!)).toUtc().toIso8601String(),
      );
      if (context.mounted) showMsg(context, 'Đã chia sẻ khóa.');
      await reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncPage<List<ShareInfo>>(
      title: 'Chia sẻ khóa',
      load: () => SmartlockApi.deviceShares(device.id),
      fab: (ctx, reload) => appFab('Chia sẻ', Icons.person_add_alt, () => _add(ctx, reload)),
      builder: (ctx, shares, reload) {
        if (shares.isEmpty) {
          return ListView(children: [
            SizedBox(
                height: 120,
                child: emptyView('Chưa chia sẻ khóa cho ai.', icon: Icons.group_outlined)),
          ]);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          itemCount: shares.length,
          itemBuilder: (_, i) {
            final s = shares[i];
            return ListCard(
              leading: iconBadge(Icons.person_outline),
              title: s.who,
              subtitle:
                  '${_permText(s.permissions)}\n${s.expiresAt == null ? 'Vĩnh viễn' : 'Hết hạn ${fmtTime(s.expiresAt)}'}',
              trailing: IconButton(
                icon: const Icon(Icons.person_remove_outlined, color: AppColors.red),
                tooltip: 'Thu hồi',
                onPressed: () async {
                  if (!await confirmDialog(ctx,
                      title: 'Thu hồi quyền của ${s.who}?',
                      text: 'Thẻ, PIN, khuôn mặt của người này cũng mất hiệu lực.',
                      okText: 'Thu hồi',
                      danger: true)) {
                    return;
                  }
                  try {
                    await SmartlockApi.revokeShare(s.id);
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

// ───────────── Khóa được người khác chia sẻ cho mình ─────────────

class IncomingSharesScreen extends StatelessWidget {
  const IncomingSharesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AsyncPage<List<ShareInfo>>(
      title: 'Khóa được chia sẻ',
      load: SmartlockApi.incomingShares,
      builder: (ctx, shares, reload) {
        if (shares.isEmpty) {
          return ListView(children: [
            SizedBox(
                height: 120,
                child: emptyView('Chưa có khóa nào được chia sẻ với bạn.', icon: Icons.group_outlined)),
          ]);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          itemCount: shares.length,
          itemBuilder: (_, i) {
            final s = shares[i];
            return ListCard(
              leading: iconBadge(Icons.lock_outline),
              title: s.deviceName,
              subtitle:
                  'Chia sẻ bởi ${s.sharedBy}\n${_permText(s.permissions)}\n${s.expiresAt == null ? 'Vĩnh viễn' : 'Hết hạn ${fmtTime(s.expiresAt)}'}',
              trailing: TextButton(
                onPressed: () async {
                  if (!await confirmDialog(ctx,
                      title: 'Rời khỏi "${s.deviceName}"?',
                      okText: 'Rời khỏi',
                      danger: true)) {
                    return;
                  }
                  try {
                    await SmartlockApi.leaveShare(s.id);
                    AppState.instance.refreshDevices(silent: true);
                    await reload();
                  } catch (e) {
                    if (ctx.mounted) showError(ctx, e);
                  }
                },
                child: const Text('Rời', style: TextStyle(color: AppColors.red)),
              ),
            );
          },
        );
      },
    );
  }
}
