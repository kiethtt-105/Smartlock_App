import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../widgets/ui.dart';

const _cmdLabels = {'LOCK': 'Khóa', 'UNLOCK': 'Mở khóa', 'REBOOT': 'Khởi động lại'};
const _statusLabels = {
  'pending': ('Đang chờ gửi', C.amber),
  'sent': ('Đã gửi tới khóa', C.amber),
  'acknowledged': ('Khóa đã thực hiện', C.green),
  'failed': ('Thất bại', C.red),
  'expired': ('Hết hạn', C.red),
};

/// Điều khiển trực tiếp một khóa: GET /devices/<id>/live/ mỗi 2 giây khi đang mở màn hình
/// (tạm dừng khi app xuống nền), gửi lệnh qua POST /devices/<id>/commands/ rồi theo dõi /commands/<id>/.
class LiveScreen extends StatefulWidget {
  final String id;
  const LiveScreen({super.key, required this.id});
  @override
  State<LiveScreen> createState() => _LiveState();
}

class _LiveState extends State<LiveScreen> with WidgetsBindingObserver {
  static const _every = Duration(seconds: 2);
  Timer? _timer;
  Map<String, dynamic>? _d;
  String? _err, _sending;
  bool _inflight = false;

  Device? get _dev {
    for (final d in store.devices) {
      if (d.id == widget.id) return d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _start();
    } else if (s == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _start() {
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(_every, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_inflight) return;
    _inflight = true;
    try {
      final r = await api.request('GET', Endpoints.deviceLive(widget.id));
      if (mounted) {
        setState(() {
          _d = r;
          _err = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _err = e.message);
    } finally {
      _inflight = false;
    }
  }

  Future<void> _send(String cmd) async {
    if (_sending != null) return;
    setState(() => _sending = cmd);
    try {
      final r = await api.request('POST', Endpoints.deviceCommand(widget.id), body: {'command': cmd});
      if (r['message'] is String) toast(r['message'] as String);
      final id = (r['command'] is Map) ? '${(r['command'] as Map)['id']}' : null;
      // Theo dõi tới khi khóa phản hồi (hoặc hết hạn / thất bại), tối đa ~20 giây.
      for (var i = 0; id != null && i < 20 && mounted; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final s = await api.request('GET', Endpoints.commandStatus(id));
        final st = (s['command'] is Map) ? '${(s['command'] as Map)['status']}' : '';
        await _tick();
        if (st == 'acknowledged' || st == 'failed' || st == 'expired') {
          if (st != 'acknowledged') toast('Lệnh ${_statusLabels[st]?.$1.toLowerCase() ?? st}.');
          break;
        }
      }
    } on ApiException catch (e) {
      toast(e.message);
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (ctx, _) {
                final d = _d, dev = _dev;
                final lock = '${d?['lock_state'] ?? dev?.lock ?? 'unknown'}';
                final (c, icon, label) = lockMeta(lock);
                final connected = d?['connected'] == true;
                final secs = (d?['seconds_ago'] as num?)?.toInt();
                final canLock = connected && (dev?.canLock ?? false) && _sending == null;
                final canUnlock = connected && (dev?.canUnlock ?? false) && _sending == null;
                final canReboot = connected && (dev?.isOwner ?? false) && _sending == null;
                final events = ((d?['events'] as List?) ?? const [])
                    .whereType<Map>()
                    .map((e) => AccessEvent.fromJson(e.cast<String, dynamic>()))
                    .toList();
                final cmds = ((d?['commands'] as List?) ?? const []).whereType<Map>().toList();
                return ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
                  Row(children: [
                    RoundBtn(Icons.arrow_back_rounded, onTap: () => context.pop()),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d?['name'] ?? dev?.name ?? 'Điều khiển'}', style: t(22, w: FontWeight.w800, ls: -.5)),
                        Text('${d?['code'] ?? dev?.code ?? ''}', style: t(12.5, color: C.sub)),
                      ]),
                    ),
                    Pill(connected ? 'Trực tiếp' : 'Mất kết nối', connected ? C.green : C.red),
                  ]),
                  const SizedBox(height: 24),
                  if (d == null && _err == null)
                    const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                  if (_err != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_err!, style: t(13.5, color: C.red), textAlign: TextAlign.center)),
                  if (d != null) ...[
                    Center(
                      child: Container(
                        width: 150, height: 150,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.withValues(alpha: .14),
                            border: Border.all(color: c.withValues(alpha: .5), width: 2)),
                        child: Icon(_sending != null ? Icons.sync_rounded : icon, color: c, size: 64),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                        child: Text(_sending != null ? 'Đang gửi ${_cmdLabels[_sending]?.toLowerCase()}…' : label,
                            style: t(28, w: FontWeight.w800, ls: -.8, color: c))),
                    if (secs != null)
                      Center(
                          child: Text(connected ? 'Cập nhật ${secs}s trước' : 'Lần cuối thấy khóa ${secs}s trước',
                              style: t(12.5, color: C.sub))),
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                          child: GradBtn('Khóa', icon: Icons.lock_rounded, filled: false,
                              loading: _sending == 'LOCK', onTap: canLock ? () => _send('LOCK') : null)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: GradBtn('Mở khóa', icon: Icons.lock_open_rounded,
                              loading: _sending == 'UNLOCK', onTap: canUnlock ? () => _send('UNLOCK') : null)),
                    ]),
                    if (dev?.isOwner ?? false) ...[
                      const SizedBox(height: 12),
                      GradBtn('Khởi động lại', icon: Icons.restart_alt_rounded, filled: false,
                          loading: _sending == 'REBOOT', onTap: canReboot ? () => _send('REBOOT') : null),
                    ],
                    const SizedBox(height: 22),
                    Row(children: [
                      MiniStat(Icons.battery_5_bar_rounded, 'Pin', '${d['battery'] ?? 0}%',
                          ((d['battery'] as num?) ?? 0) < 20 ? C.red : C.green),
                      const SizedBox(width: 10),
                      MiniStat(Icons.shield_rounded, 'Phá khóa', d['tamper'] == true ? 'CÓ' : 'Không',
                          d['tamper'] == true ? C.red : C.cyan),
                      const SizedBox(width: 10),
                      MiniStat(Icons.timer_outlined, 'Khóa tạm', d['locked_out'] == true ? 'ĐANG' : 'Không',
                          d['locked_out'] == true ? C.red : C.cyan),
                    ]),
                    if (cmds.isNotEmpty) ...[
                      const Section('Lệnh gần đây'),
                      for (final m in cmds)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Glass(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            radius: 16,
                            child: Row(children: [
                              Expanded(
                                  child: Text(_cmdLabels['${m['command']}'] ?? '${m['command']}',
                                      style: t(14.5, w: FontWeight.w600))),
                              Builder(builder: (_) {
                                final s = _statusLabels['${m['status']}'] ?? ('${m['status']}', C.sub);
                                return Pill(s.$1, s.$2);
                              }),
                            ]),
                          ),
                        ),
                    ],
                    if (events.isNotEmpty) ...[
                      const Section('Lượt mở cửa gần đây'),
                      for (int i = 0; i < events.length; i++) EventRow(events[i], last: i == events.length - 1),
                    ],
                  ],
                ]);
              },
            ),
          ),
        ),
      );
}
