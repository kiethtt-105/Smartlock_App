import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../widgets/ui.dart';
import 'account_dialogs.dart';

String _fmt(DateTime? d) => d == null
    ? 'Không hết hạn'
    : '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

/// Chạy một thao tác, hiện lỗi server bằng toast.
Future<void> _run(Future<void> Function() f, {String? ok}) async {
  try {
    await f();
    if (ok != null) toast(ok);
  } on ApiException catch (e) {
    toast(e.message);
  } catch (_) {
    toast('Đã có lỗi xảy ra, vui lòng thử lại.');
  }
}

Future<bool> _confirm(BuildContext c, String text) async =>
    await showDialog<bool>(
      context: c,
      builder: (ctx) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    ) ??
    false;

/// Khung chung: nút quay lại + tiêu đề + nội dung cuộn, tự cập nhật theo [store].
class _Shell extends StatelessWidget {
  final String title;
  final Widget Function(BuildContext) body;
  const _Shell(this.title, this.body);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (ctx, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
                Row(children: [
                  RoundBtn(Icons.arrow_back_rounded, onTap: () => context.pop()),
                  const SizedBox(width: 16),
                  Expanded(child: Text(title, style: t(24, w: FontWeight.w800, ls: -.6))),
                ]),
                const SizedBox(height: 18),
                body(ctx),
              ]),
            ),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  final String title, sub;
  final Widget? trailing;
  final List<Widget> pills;
  const _Row(this.title, this.sub, {this.trailing, this.pills = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Glass(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t(15.5, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: t(12.5, color: C.sub)),
                if (pills.isNotEmpty) ...[const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: pills)],
              ]),
            ),
            ?trailing,
          ]),
        ),
      );
}

/// Chọn khóa (lọc theo quyền) - giữ lựa chọn trong State của màn hình.
Widget _picker(List<Device> list, String? value, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Khóa'),
      items: [for (final d in list) DropdownMenuItem(value: d.id, child: Text(d.name))],
      onChanged: onChanged,
    );

String? _pick(List<Device> list, String? cur) => list.any((d) => d.id == cur) ? cur : (list.isEmpty ? null : list.first.id);

// ============================================================ Mã PIN
class PinsScreen extends StatefulWidget {
  const PinsScreen({super.key});
  @override
  State<PinsScreen> createState() => _PinsState();
}

class _PinsState extends State<PinsScreen> {
  String? dev;

  Future<void> _create(String deviceId) async {
    String? plain;
    await showForm(context,
        title: 'Tạo mã PIN',
        action: 'Tạo',
        fields: [
          ('Nhãn (vd Khách thứ 7)', false, null),
          ('Hiệu lực (phút, mặc định 1440)', false, TextInputType.number),
          ('Số lần dùng (0 = không giới hạn, mặc định 1)', false, TextInputType.number),
        ],
        submit: (v) async {
          plain = await store.createPin(deviceId,
              label: v[0], ttlMinutes: int.tryParse(v[1]) ?? 1440, maxUses: int.tryParse(v[2]) ?? 1);
          return null;
        });
    if (plain == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mã PIN của khách'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SelectableText(plain!, style: t(34, w: FontWeight.w800, ls: 4)),
          const SizedBox(height: 10),
          Text('Mã chỉ hiện một lần. Hãy gửi cho khách ngay.', style: t(13, color: C.sub)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Xong'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _Shell('Mã PIN', (ctx) {
        final devs = store.devices.where((d) => d.can('manage_pins')).toList();
        dev = _pick(devs, dev);
        final list = store.pins.where((p) => p.deviceId == dev && !p.revoked).toList();
        if (devs.isEmpty) return const EmptyBox(Icons.dialpad_rounded, 'Chưa có khóa nào', sub: 'Bạn chưa có quyền cấp mã PIN.');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _picker(devs, dev, (v) => setState(() => dev = v)),
          const SizedBox(height: 14),
          GradBtn('Tạo mã PIN', icon: Icons.add_rounded, onTap: () => _create(dev!)),
          const SizedBox(height: 18),
          if (list.isEmpty) const EmptyBox(Icons.dialpad_rounded, 'Chưa có mã PIN'),
          for (final p in list)
            _Row(
              p.label.isEmpty ? 'Mã PIN' : p.label,
              'Hết hạn: ${_fmt(p.expiresAt)} · đã dùng ${p.useCount}${p.maxUses > 0 ? '/${p.maxUses}' : ''}',
              pills: [Pill(p.validNow ? 'Đang hiệu lực' : 'Hết hiệu lực', p.validNow ? C.green : C.sub)],
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                onPressed: () async {
                  if (await _confirm(context, 'Thu hồi mã PIN này?')) await _run(() => store.revokePin(p), ok: 'Đã thu hồi.');
                },
              ),
            ),
        ]);
      });
}

// ============================================================ Thẻ NFC
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});
  @override
  State<CardsScreen> createState() => _CardsState();
}

class _CardsState extends State<CardsScreen> {
  String? dev;

  @override
  Widget build(BuildContext context) => _Shell('Thẻ NFC', (ctx) {
        final devs = store.devices.where((d) => d.can('manage_nfc')).toList();
        dev = _pick(devs, dev);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (devs.isNotEmpty) ...[
            _picker(devs, dev, (v) => setState(() => dev = v)),
            const SizedBox(height: 14),
            GradBtn('Thêm thẻ bằng UID', icon: Icons.add_rounded, onTap: () => showForm(context,
                title: 'Thêm thẻ NFC',
                action: 'Thêm',
                fields: [('UID thẻ (vd 04:A2:3B:1C)', false, null), ('Tên thẻ', false, null)],
                submit: (v) async {
                  if (v[0].isEmpty) throw ApiException('Nhập UID thẻ.');
                  await store.addCard(dev!, v[0], v[1]);
                  return 'Đã thêm thẻ.';
                })),
            const SizedBox(height: 18),
          ],
          if (store.cards.isEmpty) const EmptyBox(Icons.nfc_rounded, 'Chưa có thẻ NFC'),
          for (final c in store.cards)
            _Row(
              c.name,
              c.mine ? 'Thẻ của bạn' : 'Của ${c.owner}',
              pills: [for (final d in c.devices) Pill(d, C.violet)],
              trailing: c.mine
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(value: c.active, onChanged: (v) => _run(() => store.setCardActive(c, v))),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                        onPressed: () async {
                          if (await _confirm(context, 'Xoá thẻ "${c.name}"?')) await _run(() => store.deleteCard(c), ok: 'Đã xoá thẻ.');
                        },
                      ),
                    ])
                  : Pill(c.active ? 'Đang bật' : 'Đã tắt', c.active ? C.green : C.sub),
            ),
        ]);
      });
}

// ============================================================ Khuôn mặt
class FacesScreen extends StatelessWidget {
  const FacesScreen({super.key});

  @override
  Widget build(BuildContext context) => _Shell('Khuôn mặt', (ctx) {
        String dn(String id) => store.devices.where((d) => d.id == id).map((d) => d.name).firstOrNull ?? '';
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Đăng ký khuôn mặt mới hiện làm trên web. Ở đây bạn bật/tắt hoặc xoá hồ sơ.', style: t(13, color: C.sub)),
          const SizedBox(height: 16),
          if (store.faces.isEmpty) const EmptyBox(Icons.face_rounded, 'Chưa có hồ sơ khuôn mặt'),
          for (final f in store.faces)
            _Row(
              f.name.isEmpty ? f.user : f.name,
              '${dn(f.deviceId)} · ${f.user}',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Switch(value: f.active, onChanged: (v) => _run(() => store.setFaceActive(f, v))),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                  onPressed: () async {
                    if (await _confirm(context, 'Xoá hẳn hồ sơ khuôn mặt này?')) {
                      await _run(() => store.deleteFace(f), ok: 'Đã xoá hồ sơ.');
                    }
                  },
                ),
              ]),
            ),
        ]);
      });
}

// ============================================================ Chia sẻ khóa
const _presets = {
  'viewer': 'Chỉ xem lịch sử',
  'guest': 'Khách / người thuê',
  'family': 'Thành viên gia đình',
  'manager': 'Người trông nhà',
};

class SharesScreen extends StatefulWidget {
  const SharesScreen({super.key});
  @override
  State<SharesScreen> createState() => _SharesState();
}

class _SharesState extends State<SharesScreen> {
  String? dev;

  Future<void> _share(String deviceId) async {
    final preset = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(title: const Text('Chọn vai trò'), children: [
        for (final e in _presets.entries) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, e.key), child: Text(e.value)),
      ]),
    );
    if (preset == null || !mounted) return;
    await showForm(context,
        title: 'Chia sẻ (${_presets[preset]})',
        action: 'Chia sẻ',
        fields: [('Email hoặc tên đăng nhập', false, TextInputType.emailAddress)],
        submit: (v) async {
          if (v[0].isEmpty) throw ApiException('Nhập email hoặc tên đăng nhập.');
          await store.shareDevice(deviceId, v[0], preset);
          return 'Đã chia sẻ khóa.';
        });
  }

  @override
  Widget build(BuildContext context) => _Shell('Chia sẻ khóa', (ctx) {
        final mine = store.devices.where((d) => d.isOwner).toList();
        dev = _pick(mine, dev);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (mine.isNotEmpty) ...[
            _picker(mine, dev, (v) => setState(() => dev = v)),
            const SizedBox(height: 14),
            GradBtn('Chia sẻ khóa này', icon: Icons.person_add_alt_1_rounded, onTap: () => _share(dev!)),
          ],
          const Section('Bạn đã chia sẻ'),
          if (store.sharesOut.isEmpty) const EmptyBox(Icons.share_rounded, 'Chưa chia sẻ cho ai'),
          for (final s in store.sharesOut)
            _Row(
              s.who,
              '${s.deviceName} · hết hạn: ${_fmt(s.expiresAt)}',
              pills: [for (final p in s.permissions) Pill(p, C.cyan)],
              trailing: IconButton(
                icon: const Icon(Icons.person_remove_rounded, color: C.red),
                onPressed: () async {
                  if (await _confirm(context, 'Thu hồi quyền của ${s.who}?')) await _run(() => store.revokeShare(s), ok: 'Đã thu hồi.');
                },
              ),
            ),
          const Section('Được chia sẻ cho bạn'),
          if (store.sharesIn.isEmpty) const EmptyBox(Icons.key_rounded, 'Chưa có khóa nào được chia sẻ'),
          for (final s in store.sharesIn)
            _Row(
              s.deviceName,
              'Từ ${s.sharedBy} · hết hạn: ${_fmt(s.expiresAt)}',
              pills: [for (final p in s.permissions) Pill(p, C.cyan)],
              trailing: TextButton(
                onPressed: () async {
                  if (await _confirm(context, 'Rời khỏi "${s.deviceName}"?')) await _run(() => store.leaveShare(s), ok: 'Đã rời khóa.');
                },
                child: const Text('Rời'),
              ),
            ),
        ]);
      });
}
