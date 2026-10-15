import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../nav.dart';
import '../state/prefs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';
import 'cards_screen.dart';
import 'faces_screen.dart';
import 'history_screen.dart';
import 'lock_settings_screen.dart';
import 'pins_screen.dart';
import 'shares_screen.dart';

class _Shortcut {
  final String label;
  final IconData icon;
  final Widget Function(LockDevice d) page;

  const _Shortcut(this.label, this.icon, this.page);
}

class LockDetailScreen extends StatefulWidget {
  final LockDevice device;

  const LockDetailScreen({super.key, required this.device});

  @override
  State<LockDetailScreen> createState() => _LockDetailScreenState();
}

class _LockDetailScreenState extends State<LockDetailScreen> {
  late LockDevice _dev;
  LiveState? _live;
  String? _loadingText = 'Đang cố lấy trạng thái khóa';
  bool _busy = false;
  bool _tapToUnlock = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _dev = widget.device;
    AppPrefs.getBool(AppPrefs.tapToUnlock).then((v) => _tapToUnlock = v);
    _firstLoad();
    // App poll 3 giây/lần khi đang mở màn hình điều khiển.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _firstLoad() async {
    try {
      final results = await Future.wait([SmartlockApi.live(_dev.id), SmartlockApi.device(_dev.id)]);
      if (!mounted) return;
      setState(() {
        _live = results[0] as LiveState;
        _dev = results[1] as LockDevice;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingText = null);
    }
  }

  Future<void> _poll() async {
    if (_busy || !mounted) return;
    try {
      final l = await SmartlockApi.live(_dev.id);
      if (mounted) setState(() => _live = l);
    } catch (_) {
      // lỗi mạng thoáng qua: bỏ qua, 3 giây sau thử lại
    }
  }

  Future<void> _reloadDevice() async {
    try {
      final d = await SmartlockApi.device(_dev.id);
      if (mounted) setState(() => _dev = d);
    } catch (_) {}
  }

  Future<void> _send(String command) async {
    if (_busy) return;
    if (!_dev.can(command)) {
      showMsg(context, 'Bạn không có quyền ${command == 'LOCK' ? 'khóa' : 'mở khóa'} cửa này.',
          error: true);
      return;
    }
    setState(() {
      _busy = true;
      _loadingText = command == 'LOCK' ? 'Đang khóa…' : 'Đang mở khóa…';
    });
    try {
      var cmd = await SmartlockApi.sendCommand(_dev.id, command);
      // Chờ khóa phản hồi (tối đa ~20 giây).
      for (var i = 0; i < 20 && !cmd.isDone; i++) {
        await Future.delayed(const Duration(seconds: 1));
        cmd = await SmartlockApi.commandStatus(cmd.id);
      }
      if (!mounted) return;
      switch (cmd.status) {
        case 'acknowledged':
          showMsg(context, command == 'LOCK' ? 'Đã khóa cửa.' : 'Đã mở khóa.');
        case 'failed':
          showMsg(context, 'Khóa không thực hiện được lệnh.', error: true);
        case 'expired':
          showMsg(context, 'Khóa không phản hồi. Hãy thử lại.', error: true);
        default:
          showMsg(context, 'Lệnh đã gửi, đang chờ khóa phản hồi…');
      }
    } on ApiException catch (e) {
      if (mounted) showMsg(context, e.message, error: true);
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _loadingText = null;
      });
      _poll();
    }
  }

  void _onTap() {
    if (!_tapToUnlock) {
      showMsg(context, 'Đang tắt "Chạm để mở khóa". Hãy bật trong Cài đặt của app.');
      return;
    }
    _send('UNLOCK');
  }

  List<_Shortcut> get _shortcuts => [
        if (_dev.can('view_history'))
          _Shortcut('Lịch sử', Icons.history, (d) => HistoryScreen(device: d)),
        _Shortcut('Cài đặt', Icons.settings_outlined, (d) => LockSettingsScreen(device: d)),
        if (_dev.can('manage_pins'))
          _Shortcut('Mã PIN', Icons.pin_outlined, (d) => PinsScreen(device: d)),
        if (_dev.can('manage_nfc'))
          _Shortcut('Thẻ NFC', Icons.nfc, (d) => CardsScreen(device: d)),
        if (_dev.can('manage_face_profiles'))
          _Shortcut('Khuôn mặt', Icons.face_outlined, (d) => FacesScreen(device: d)),
        if (_dev.isOwner)
          _Shortcut('Chia sẻ', Icons.share_outlined, (d) => DeviceSharesScreen(device: d)),
      ];

  @override
  Widget build(BuildContext context) {
    final live = _live;
    final state = live?.lockState ?? _dev.lockState;
    final battery = live?.battery ?? _dev.battery;
    final connected = live?.connected ?? _dev.isOnline;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TitleBar(
                    title: 'Smartlock',
                    onBack: () => Navigator.pop(context),
                    trailing: IconButton(
                      onPressed: () async {
                        setState(() => _loadingText = 'Đang làm mới…');
                        await _firstLoad();
                      },
                      icon: const Icon(Icons.sync, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        Flexible(
                          flex: 3,
                          child: Text(_dev.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 24)),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.battery_full,
                                    color: (battery != null && battery < 20)
                                        ? AppColors.red
                                        : AppColors.green),
                                const SizedBox(width: 4),
                                Text(battery == null ? '--' : '$battery%',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    connected ? 'Đã kết nối' : 'Mất kết nối (chỉ mở được bằng Bluetooth/NFC/PIN)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: connected ? AppColors.green : AppColors.textSecondary, fontSize: 13),
                  ),
                  if (live?.tamper == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: statusChip('Phát hiện tác động vào khóa', AppColors.red),
                    ),
                  if (live?.lockedOut == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: statusChip('Khóa đang tạm khóa do nhập sai nhiều lần', AppColors.red),
                    ),
                  const SizedBox(height: 20),
                  _bigButton(state),
                  const SizedBox(height: 16),
                  const Text('Chạm để mở khóa, nhấn lâu để khóa',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
                  const SizedBox(height: 28),
                  _shortcutCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_loadingText != null) LoadingOverlay(text: _loadingText),
        ],
      ),
    );
  }

  Widget _bigButton(String state) {
    final IconData icon;
    final Color color;
    switch (state) {
      case 'locked':
        icon = Icons.lock;
        color = AppColors.blue;
      case 'unlocked':
        icon = Icons.lock_open;
        color = AppColors.green;
      case 'jammed':
        icon = Icons.warning_amber_rounded;
        color = AppColors.red;
      default:
        icon = Icons.help_outline;
        color = AppColors.textSecondary;
    }
    return Container(
      width: 300,
      height: 300,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF202024)),
      child: Container(
        width: 250,
        height: 250,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF17171A)),
        child: GestureDetector(
          onTap: _onTap,
          onLongPress: () => _send('LOCK'),
          child: Container(
            width: 212,
            height: 212,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2E3138), Color(0xFF1B1D22)],
              ),
              border: Border.all(color: const Color(0xFF3A3F4A), width: 2),
            ),
            child: Icon(icon, color: color, size: 72),
          ),
        ),
      ),
    );
  }

  Widget _shortcutCard() {
    final items = _shortcuts;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 4) {
      final chunk = items.skip(i).take(4).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 20));
      rows.add(Row(
        children: [
          for (final s in chunk) Expanded(child: _shortcutItem(s)),
          for (var k = chunk.length; k < 4; k++) const Expanded(child: SizedBox()),
        ],
      ));
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF232326),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: rows),
    );
  }

  Widget _shortcutItem(_Shortcut s) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await pushPage(context, s.page(_dev));
        _reloadDevice();
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2E2E32)),
            child: Icon(s.icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(s.label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }
}
