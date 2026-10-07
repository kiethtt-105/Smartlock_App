import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'form_pages.dart' show ErrorBox;

const _methods = {
  'RFID': 'Thẻ RFID',
  'PIN': 'Mã PIN',
  'FACE': 'Khuôn mặt',
  'BLE': 'Bluetooth',
  'NFC_PHONE': 'NFC điện thoại',
};

class _Ev {
  final String method, who, reason, deviceName;
  final bool success;
  final DateTime at;
  final double? confidence;
  _Ev(Map<String, dynamic> j)
      : method = '${j['method'] ?? ''}'.toUpperCase(),
        who = '${j['who'] ?? ''}',
        reason = '${j['reason'] ?? ''}',
        deviceName = '${j['device_name'] ?? ''}',
        success = j['success'] == true,
        confidence = (j['confidence'] as num?)?.toDouble(),
        at = DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now();
}

String _clock(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Lịch sử ra vào đầy đủ: GET /api/app/history/ (lọc theo khoá, kênh, kết quả; phân trang).
class HistoryScreen extends StatefulWidget {
  final String? deviceId;
  const HistoryScreen({super.key, this.deviceId});
  @override
  State<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<HistoryScreen> {
  static const _size = 20;
  final _items = <_Ev>[];
  String? _device, _method, _success; // _success: '1' | '0' | null
  int _page = 0;
  bool _hasNext = false, _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _device = widget.deviceId;
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _err = null;
      if (reset) {
        _page = 0;
        _items.clear();
        _hasNext = false;
      }
    });
    try {
      final r = await api.request('GET', Endpoints.history, query: {
        'page': '${_page + 1}',
        'page_size': '$_size',
        if (_device != null) 'device': _device!,
        if (_method != null) 'method': _method!,
        if (_success != null) 'success': _success!,
      });
      final list = ((r['items'] as List?) ?? const []).whereType<Map>();
      _items.addAll(list.map((e) => _Ev(e.cast<String, dynamic>())));
      _page = (r['page'] as num?)?.toInt() ?? _page + 1;
      _hasNext = r['has_next'] == true;
    } on ApiException catch (e) {
      _err = e.message;
    } catch (_) {
      _err = 'Đã có lỗi xảy ra, vui lòng thử lại.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _chip(String label, bool on, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => tap()),
      );

  void _set(void Function() f) {
    setState(f);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final devices = store.devices.where((d) => d.can('view_history')).toList();
    return Scaffold(
      body: GlowBg(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _load(reset: true),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
              Row(children: [
                RoundBtn(Icons.arrow_back_rounded, onTap: () => context.canPop() ? context.pop() : context.go('/access')),
                const SizedBox(width: 16),
                Expanded(child: Text('Lịch sử ra vào', style: t(24, w: FontWeight.w800, ls: -.6))),
              ]),
              const SizedBox(height: 16),
              if (devices.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('Tất cả khoá', _device == null, () => _set(() => _device = null)),
                    for (final d in devices) _chip(d.name, _device == d.id, () => _set(() => _device = d.id)),
                  ]),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip('Mọi kênh', _method == null, () => _set(() => _method = null)),
                  for (final e in _methods.entries) _chip(e.value, _method == e.key, () => _set(() => _method = e.key)),
                ]),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _chip('Mọi kết quả', _success == null, () => _set(() => _success = null)),
                  _chip('Thành công', _success == '1', () => _set(() => _success = '1')),
                  _chip('Bị từ chối', _success == '0', () => _set(() => _success = '0')),
                ]),
              ),
              const SizedBox(height: 14),
              if (_err != null) ErrorBox(_err!),
              if (_items.isEmpty && !_loading && _err == null)
                const Padding(
                    padding: EdgeInsets.only(top: 60), child: EmptyBox(Icons.history_rounded, 'Chưa có lượt ra vào')),
              for (final e in _items)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: _Row(e)),
              if (_loading)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
              if (_hasNext && !_loading) GradBtn('Tải thêm', filled: false, onTap: () => _load()),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final _Ev e;
  const _Row(this.e);

  @override
  Widget build(BuildContext context) {
    final c = e.success ? C.cyan : C.red;
    final icon = switch (e.method) {
      'RFID' || 'NFC_PHONE' => Icons.nfc_rounded,
      'PIN' => Icons.dialpad_rounded,
      'FACE' => Icons.face_rounded,
      'BLE' => Icons.bluetooth_rounded,
      _ => Icons.meeting_room_rounded,
    };
    final status = e.success ? 'Thành công' : (e.reason.isEmpty ? 'Bị từ chối' : e.reason);
    return Glass(
      padding: const EdgeInsets.all(14),
      radius: 18,
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .14)),
          child: Icon(icon, size: 20, color: c),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.who.isEmpty ? 'Không xác định' : e.who, style: t(15, w: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${_methods[e.method] ?? e.method} · $status', style: t(12.5, color: e.success ? C.sub : C.red)),
            Text(
                '${e.deviceName}${e.confidence == null ? '' : ' · độ tin cậy ${e.confidence!.toStringAsFixed(2)}'}',
                style: t(12, color: C.sub)),
          ]),
        ),
        Text(_clock(e.at), style: t(12, color: C.sub)),
      ]),
    );
  }
}
