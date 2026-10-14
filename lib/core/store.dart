import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const kSv = '0000ffe0-0000-1000-8000-00805f9b34fb'; // cùng UUID với bản web
const kCh = '0000ffe1-0000-1000-8000-00805f9b34fb';
int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class Store extends ChangeNotifier with WidgetsBindingObserver {
  Map<String, dynamic> S = {};
  String? etag;
  bool online = true, _syncing = false;
  final busy = <String>{};
  Map<String, dynamic> tickets = {}; // deviceId -> {ticket, expires_at, ttl}
  Timer? _t;
  late SharedPreferences _p;

  List get devices => (S['devices'] as List?) ?? [];
  List list(String k) => (S[k] as List?) ?? [];

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try {
      S = jsonDecode(_p.getString('snap') ?? '{}');
      tickets = jsonDecode(_p.getString('tickets') ?? '{}');
    } catch (_) {}
    etag = _p.getString('etag');
    WidgetsBinding.instance.addObserver(this);
  }

  // ---------- CẬP NHẬT DỮ LIỆU ----------
  // Mở app: hiện cache ngay -> sync ETag/304 mỗi 4s khi foreground (15s khi mất mạng) -> nền thì dừng.
  void start() {
    _t?.cancel();
    () async {
      await sync();
      _t = Timer(Duration(seconds: online ? 4 : 15), start);
    }();
  }

  void stop() => _t?.cancel();

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) => s == AppLifecycleState.resumed ? start() : stop();

  Future<void> sync() async {
    if (_syncing) return;
    _syncing = true;
    final r = await Api.i.call('GET', 'snapshot/', etag: etag);
    _syncing = false;
    final was = online;
    online = !r.net;
    if (r.ok && !r.notModified) {
      S = r.d;
      etag = r.etag;
      await _p.setString('snap', jsonEncode(S));
      if (etag != null) await _p.setString('etag', etag!);
      notifyListeners();
    } else if (was != online) {
      notifyListeners();
    }
    if (r.ok) prefetchTickets();
  }

  Future<void> reset() async {
    stop();
    S = {};
    etag = null;
    tickets = {};
    await _p.clear();
    notifyListeners();
  }

  // ---------- VÉ BLE CHO MỞ KHÓA OFFLINE ----------
  // Khi có mạng: xin sẵn vé cho mỗi khóa bật Bluetooth, lưu máy. Hết mạng vẫn dùng vé còn hạn.
  Future<void> prefetchTickets() async {
    for (final d in devices) {
      if (d['bluetooth_enabled'] != true) continue;
      final id = d['id'] as String, t = tickets[id];
      final ttl = (t?['ttl'] ?? 0) as int, left = (t?['expires_at'] ?? 0) - _now();
      if (t != null && left > ttl * 0.5) continue; // còn > nửa hạn thì thôi
      await fetchTicket(id);
    }
  }

  Future<Map?> fetchTicket(String id) async {
    final r = await Api.i.call('POST', 'devices/$id/ble-ticket/', body: {});
    if (!r.ok) return null; // 403 (không có quyền BLE) / 409 (kênh tắt) -> bỏ qua
    tickets[id] = {'ticket': r.d['ticket'], 'expires_at': r.d['expires_at'], 'ttl': r.d['ttl_seconds'] ?? 60};
    await _p.setString('tickets', jsonEncode(tickets));
    return tickets[id];
  }

  // ---------- LỆNH: CLOUD TRƯỚC, BLE DỰ PHÒNG ----------
  /// Trả null nếu thành công, hoặc thông báo lỗi.
  Future<String?> act(Map d, String cmd) async {
    final id = d['id'] as String;
    busy.add(id);
    notifyListeners();
    try {
      if (online && d['status'] == 'online' && d['wifi_enabled'] != false) {
        final r = await Api.i.call('POST', 'devices/$id/commands/', body: {'command': cmd});
        if (r.ok) {
          final cid = r.d['command']['id'];
          for (var i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 1500));
            final s = await Api.i.call('GET', 'commands/$cid/');
            if (s.net) break;
            final st = s.d['command']?['status'];
            if (st == 'acknowledged') {
              await sync();
              return null;
            }
            if (st == 'failed' || st == 'expired') return 'Khóa không phản hồi lệnh.';
          }
          return 'Chưa nhận được xác nhận từ khóa.';
        }
        const fallback = {'DEVICE_OFFLINE', 'WIFI_DISABLED', 'PUBLISH_FAILED'};
        if (!r.net && !fallback.contains(r.code)) return r.msg; // lỗi thật (403, trùng lệnh...) -> báo, không dùng BLE
      }
      if (cmd != 'UNLOCK') return 'Cần có mạng để gửi lệnh này.';
      return await unlockBle(d);
    } finally {
      busy.remove(id);
      notifyListeners();
    }
  }

  Future<String?> unlockBle(Map d) async {
    final id = d['id'] as String;
    if (d['bluetooth_enabled'] != true) return 'Khóa này chưa bật Bluetooth.';
    Map? t = tickets[id];
    if (t == null || (t['expires_at'] as int) - _now() < 3) t = online ? await fetchTicket(id) : null;
    if (t == null) return 'Chưa có vé offline còn hạn. Hãy mở app khi có mạng để tải vé.';
    final err = await _bleSend(d, t['ticket']);
    return err; // vé là chữ ký HMAC có hạn, dùng lại được tới khi hết hạn nên giữ nguyên
  }

  Future<String?> _bleSend(Map d, String ticket) async {
    final mac = (d['mac_address'] ?? '').toString().toUpperCase(), code = (d['device_code'] ?? '').toString();
    BluetoothDevice? dev;
    StreamSubscription? sub;
    try {
      final c = Completer<BluetoothDevice?>();
      sub = FlutterBluePlus.scanResults.listen((rs) {
        for (final r in rs) {
          final byMac = mac.isNotEmpty && r.device.remoteId.str.toUpperCase() == mac;
          final byName = code.isNotEmpty && r.advertisementData.advName.contains(code);
          if ((byMac || byName) && !c.isCompleted) c.complete(r.device);
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      dev = await c.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
      await FlutterBluePlus.stopScan();
      if (dev == null) return 'Không tìm thấy khóa gần đây. Hãy lại gần cửa hơn.';
      await dev.connect(timeout: const Duration(seconds: 8));
      final svs = await dev.discoverServices();
      final ch = svs.firstWhere((s) => s.uuid == Guid(kSv)).characteristics.firstWhere((x) => x.uuid == Guid(kCh));
      final bytes = utf8.encode('$ticket\n');
      for (var i = 0; i < bytes.length; i += 20) {
        await ch.write(bytes.sublist(i, min(i + 20, bytes.length)), withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 30));
      }
      return null;
    } catch (e) {
      return 'Bluetooth lỗi: $e';
    } finally {
      await sub?.cancel();
      try {
        await dev?.disconnect();
      } catch (_) {}
    }
  }
}