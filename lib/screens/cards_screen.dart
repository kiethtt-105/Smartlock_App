import 'dart:async';

import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/async_page.dart';
import '../widgets/helpers.dart';

/// Danh sách thẻ NFC. [device] != null: chỉ thẻ của khóa đó (và cho thêm thẻ nếu là chủ khóa).
class CardsScreen extends StatelessWidget {
  final LockDevice? device;

  const CardsScreen({super.key, this.device});

  Future<List<CardInfo>> _load() async {
    final all = await SmartlockApi.cards();
    final d = device;
    if (d == null) return all;
    return all.where((c) => c.devices.any((l) => l.deviceId == d.id)).toList();
  }

  Future<void> _addMenu(BuildContext context, Future<void> Function() reload) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.nfc, color: AppColors.blue),
              title: const Text('Quét thẻ tại khóa'),
              subtitle: const Text('Chạm thẻ vào đầu đọc trên khóa'),
              onTap: () => Navigator.pop(ctx, 'scan'),
            ),
            ListTile(
              leading: const Icon(Icons.keyboard, color: AppColors.blue),
              title: const Text('Nhập UID thủ công'),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'scan') {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EnrollDialog(deviceId: device!.id),
      );
    } else {
      final uid = await promptDialog(context, title: 'UID thẻ', hint: 'VD: 04A1B2C3', okText: 'Tiếp');
      if (uid == null || uid.isEmpty || !context.mounted) return;
      final name = await promptDialog(context, title: 'Tên thẻ (tuỳ chọn)', okText: 'Đăng ký') ?? '';
      try {
        await SmartlockApi.registerCardUid(device!.id, uid, name);
        if (context.mounted) showMsg(context, 'Đã đăng ký thẻ.');
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = device != null && device!.isOwner;
    return AsyncPage<List<CardInfo>>(
      title: 'Thẻ NFC',
      load: _load,
      fab: canAdd ? (ctx, reload) => appFab('Thêm thẻ', Icons.add, () => _addMenu(ctx, reload)) : null,
      builder: (ctx, cards, reload) {
        if (cards.isEmpty) {
          return ListView(children: [
            SizedBox(height: 120, child: emptyView('Chưa có thẻ NFC nào.', icon: Icons.nfc)),
          ]);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
          itemCount: cards.length,
          itemBuilder: (_, i) => _cardTile(ctx, cards[i], reload),
        );
      },
    );
  }

  Widget _cardTile(BuildContext ctx, CardInfo c, Future<void> Function() reload) {
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        await reload();
      } catch (e) {
        if (ctx.mounted) showError(ctx, e);
      }
    }

    final link = device == null
        ? null
        : c.devices.where((l) => l.deviceId == device!.id).cast<CardDeviceLink?>().firstWhere(
            (_) => true,
            orElse: () => null);

    Widget? trailing;
    if (c.isMine) {
      trailing = PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (v) async {
          if (v == 'rename') {
            final n = await promptDialog(ctx, title: 'Đổi tên thẻ', initial: c.name);
            if (n != null) await run(() => SmartlockApi.renameCard(c.id, n));
          } else if (v == 'toggle') {
            await run(() => SmartlockApi.setCardActive(c.id, !c.isActive));
          } else if (v == 'delete') {
            if (await confirmDialog(ctx,
                title: 'Xóa thẻ?', text: 'Thẻ sẽ bị gỡ khỏi mọi khóa.', okText: 'Xóa', danger: true)) {
              await run(() => SmartlockApi.deleteCard(c.id));
            }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
          PopupMenuItem(value: 'toggle', child: Text(c.isActive ? 'Tắt thẻ' : 'Bật thẻ')),
          const PopupMenuItem(value: 'delete', child: Text('Xóa thẻ')),
        ],
      );
    } else if (link != null && device!.isOwner) {
      trailing = Switch(
        value: link.isActive,
        onChanged: (v) => run(() => SmartlockApi.setCardLinkActive(c.id, device!.id, v)),
      );
    }

    return ListCard(
      leading: iconBadge(Icons.nfc, color: c.isActive ? AppColors.blue : AppColors.textSecondary),
      title: c.title,
      subtitle:
          '${c.isMine ? 'Thẻ của bạn' : 'Của ${c.owner}'}${c.isActive ? '' : ' · đã tắt'}\n${c.devices.map((l) => l.deviceName).join(', ')}',
      trailing: trailing,
    );
  }
}

/// Hộp quét thẻ tại khóa: mở cửa sổ 60 giây, hỏi lại 2 giây/lần.
class _EnrollDialog extends StatefulWidget {
  final String deviceId;

  const _EnrollDialog({required this.deviceId});

  @override
  State<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends State<_EnrollDialog> {
  Timer? _timer;
  bool _active = false;
  int _left = 0;
  String _since = '';
  List<String> _done = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final e = await SmartlockApi.enrollStart(widget.deviceId);
      if (!mounted) return;
      setState(() {
        _active = e['active'] == true;
        _left = (e['seconds_left'] as num?)?.toInt() ?? 0;
        _since = (e['since'] ?? '').toString();
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (e) {
      if (mounted) setState(() => _error = errMsg(e));
    }
  }

  Future<void> _poll() async {
    try {
      final e = await SmartlockApi.enrollPoll(widget.deviceId, _since);
      if (!mounted) return;
      final reg = ((e['registered'] as List?) ?? [])
          .map((x) => ((x as Map)['name'] ?? '').toString())
          .toList();
      setState(() {
        _active = e['active'] == true;
        _left = (e['seconds_left'] as num?)?.toInt() ?? 0;
        _done = reg;
      });
      if (reg.isNotEmpty || !_active) _timer?.cancel();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_active && _done.isEmpty) {
      SmartlockApi.enrollCancel(widget.deviceId).catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _done.isNotEmpty;
    final expired = !_active && _error == null && _since.isNotEmpty && !finished;
    return AlertDialog(
      title: const Text('Quét thẻ tại khóa'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.red))
          else if (finished) ...[
            const Icon(Icons.check_circle, color: AppColors.green, size: 56),
            const SizedBox(height: 12),
            const Text('Đã đăng ký thẻ mới.'),
          ] else if (expired) ...[
            const Icon(Icons.timer_off_outlined, size: 56),
            const SizedBox(height: 12),
            const Text('Hết thời gian chờ. Hãy thử lại.'),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Hãy chạm thẻ vào đầu đọc trên khóa.'),
            const SizedBox(height: 8),
            Text('Còn $_left giây', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(finished || expired || _error != null ? 'Đóng' : 'Hủy'),
        ),
      ],
    );
  }
}
