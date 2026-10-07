import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../widgets/ui.dart';
import 'form_pages.dart' show ErrorBox, showForm;

class _Reader {
  final String id, name, mode;
  final bool active, autoRegister;
  final int secondsLeft;
  _Reader(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = '${j['name'] ?? ''}'.isEmpty ? 'Đầu đọc' : '${j['name']}',
        mode = '${j['reader_mode'] ?? ''}',
        active = j['is_active'] == true,
        autoRegister = j['auto_register'] == true,
        secondsLeft = (j['auto_register_seconds_left'] as num?)?.toInt() ?? 0;
}

/// Đầu đọc NFC gắn với một khóa (GET/POST /devices/<id>/nfc-readers/, PATCH /nfc-readers/<id>/).
/// Xem/bật tắt cần quyền manage_nfc; thêm đầu đọc, bật tắt, mở cửa sổ quẹt-để-đăng-ký: chỉ chủ khóa.
class NfcScreen extends StatefulWidget {
  final String deviceId;
  const NfcScreen({super.key, required this.deviceId});
  @override
  State<NfcScreen> createState() => _NfcState();
}

class _NfcState extends State<NfcScreen> {
  List<_Reader> _readers = [];
  bool _loading = true;
  String? _err;
  Timer? _timer;

  Device? get _dev {
    for (final d in store.devices) {
      if (d.id == widget.deviceId) return d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await api.request('GET', Endpoints.deviceReaders(widget.deviceId));
      _readers = ((r['readers'] as List?) ?? const []).whereType<Map>().map((e) => _Reader(e.cast<String, dynamic>())).toList();
      _err = null;
    } on ApiException catch (e) {
      _err = e.message;
    }
    if (mounted) setState(() => _loading = false);
    // Cửa sổ đăng ký chỉ mở ~60 giây: cập nhật bộ đếm khi còn đầu đọc đang mở.
    _timer?.cancel();
    if (mounted && _readers.any((r) => r.autoRegister)) {
      _timer = Timer(const Duration(seconds: 3), _load);
    }
  }

  Future<void> _patch(_Reader r, Map<String, dynamic> body) async {
    try {
      await api.request('PATCH', Endpoints.reader(r.id), body: body);
      await _load();
    } on ApiException catch (e) {
      toast(e.message);
    }
  }

  Future<void> _add() => showForm(context,
      title: 'Thêm đầu đọc',
      action: 'Thêm',
      initial: const ['Đầu đọc mô phỏng'],
      fields: [('Tên đầu đọc', false, null)],
      submit: (v) async {
        await api.request('POST', Endpoints.deviceReaders(widget.deviceId), body: {'name': v[0]});
        await _load();
        return 'Đã thêm đầu đọc.';
      });

  @override
  Widget build(BuildContext context) {
    final dev = _dev;
    final owner = dev?.isOwner ?? false;
    return Scaffold(
      body: GlowBg(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
              Row(children: [
                RoundBtn(Icons.arrow_back_rounded, onTap: () => context.pop()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Đầu đọc NFC', style: t(24, w: FontWeight.w800, ls: -.6)),
                    if (dev != null) Text(dev.name, style: t(12.5, color: C.sub)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              if (dev != null && !dev.nfc) const ErrorBox('NFC của khóa đang tắt. Bật lại trong phần cài đặt khóa.'),
              if (_err != null) ErrorBox(_err!),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
              if (!_loading && _readers.isEmpty && _err == null)
                const Padding(
                    padding: EdgeInsets.only(top: 40), child: EmptyBox(Icons.nfc_rounded, 'Chưa có đầu đọc nào')),
              for (final r in _readers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Glass(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.nfc_rounded, color: C.violet),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.name, style: t(16, w: FontWeight.w700)),
                          Text(r.mode == 'simulated' ? 'Mô phỏng' : r.mode, style: t(12.5, color: C.sub)),
                        ])),
                        Pill(r.active ? 'Đang bật' : 'Đã tắt', r.active ? C.green : C.sub),
                        const SizedBox(width: 8),
                      ]),
                      if (owner) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Hoạt động'),
                          value: r.active,
                          onChanged: (dev?.nfc ?? true) ? (v) => _patch(r, {'is_active': v}) : null,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Quẹt thẻ để đăng ký'),
                          subtitle: Text(
                              r.autoRegister
                                  ? 'Đang mở, còn ${r.secondsLeft}s. Quẹt thẻ mới vào đầu đọc.'
                                  : 'Mở cửa sổ ngắn để thẻ quẹt vào được tự đăng ký.',
                              style: t(12.5, color: C.sub)),
                          value: r.autoRegister,
                          onChanged: (dev?.nfc ?? true) && r.active ? (v) => _patch(r, {'auto_register': v}) : null,
                        ),
                      ],
                    ]),
                  ),
                ),
              if (owner) ...[
                const SizedBox(height: 6),
                GradBtn('Thêm đầu đọc', icon: Icons.add_rounded, filled: false, onTap: (dev?.nfc ?? true) ? _add : null),
              ],
              const SizedBox(height: 12),
              GradBtn('Quản lý thẻ NFC', icon: Icons.credit_card_rounded, onTap: () => context.push('/access/cards')),
            ]),
          ),
        ),
      ),
    );
  }
}
