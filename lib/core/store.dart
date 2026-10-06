import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'toast.dart';

DateTime _dt(dynamic v) => (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

class Device {
  final String id, name, code;
  final bool online, tamper, lockedOut, isOwner, wifi;
  final int battery;
  final List<String> permissions;
  String lock; // locked | unlocked | jammed | unknown
  bool busy = false;
  Device({
    required this.id,
    required this.name,
    required this.code,
    required this.online,
    required this.battery,
    required this.lock,
    this.tamper = false,
    this.lockedOut = false,
    this.isOwner = false,
    this.wifi = true,
    this.permissions = const [],
  });

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: '${j['id']}',
        name: '${j['name'] ?? 'Thiết bị'}',
        code: '${j['device_code'] ?? ''}',
        online: j['status'] == 'online',
        battery: (j['battery_level'] as num?)?.toInt() ?? 0,
        lock: '${j['lock_state'] ?? 'unknown'}',
        tamper: j['tamper'] == true || j['is_tampered'] == true,
        lockedOut: j['locked_out'] == true || j['is_locked_out'] == true,
        isOwner: j['is_owner'] == true,
        wifi: j['wifi_enabled'] != false,
        permissions: ((j['permissions'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  bool _can(String p) => online && wifi && (isOwner || permissions.contains(p));
  bool get canLock => _can('LOCK');
  bool get canUnlock => _can('UNLOCK');
}

class Note {
  final String id, sev, title, body; // sev: info | warning | critical
  final DateTime at;
  bool read;
  Note(this.id, this.sev, this.title, this.body, this.at, {this.read = false});

  factory Note.fromJson(Map<String, dynamic> j) => Note('${j['id']}', '${j['severity'] ?? 'info'}', '${j['title'] ?? ''}',
      '${j['message'] ?? ''}', _dt(j['created_at']),
      read: j['is_read'] == true);
}

class AccessEvent {
  final String method, who, reason;
  final bool success;
  final DateTime at;
  AccessEvent(this.method, this.who, this.success, this.at, {this.reason = ''});

  factory AccessEvent.fromJson(Map<String, dynamic> j) => AccessEvent(
      '${j['method'] ?? ''}'.toUpperCase(), '${j['who'] ?? '—'}', j['success'] == true, _dt(j['created_at']),
      reason: '${j['reason'] ?? ''}');
}

String ago(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'vừa xong';
  if (m < 60) return '$m phút trước';
  if (m < 60 * 24) return '${m ~/ 60} giờ trước';
  return '${m ~/ (60 * 24)} ngày trước';
}

class Store extends ChangeNotifier {
  static const _pollEvery = Duration(seconds: 4);

  List<Device> devices = [];
  List<Note> notes = [];
  List<AccessEvent> events = [];
  String userName = '', userEmail = '';
  bool loaded = false;

  final _busyIds = <String>{};
  final _dismissed = <String>{}; // API chưa có xoá thông báo -> chỉ ẩn trên máy này
  Timer? _timer;
  bool _inflight = false, _polling = false;

  int get unread => notes.where((n) => !n.read).length;

  // ---------------------------------------------------------------- tải dữ liệu
  Future<void> refresh({bool force = false}) async {
    final b = await api.snapshot(force: force);
    if (b == null) return; // 304: không đổi
    _apply(b);
  }

  void _apply(Map<String, dynamic> b) {
    List<Map<String, dynamic>> list(String k) =>
        ((b[k] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

    devices = list('devices').map(Device.fromJson).toList()..forEach((d) => d.busy = _busyIds.contains(d.id));
    notes = list('notifications').map(Note.fromJson).where((n) => !_dismissed.contains(n.id)).toList();
    events = list('history').map(AccessEvent.fromJson).toList();
    final u = b['user'];
    if (u is Map) userEmail = '${u['email'] ?? ''}';
    if (u is Map) userName = '${u['full_name'] ?? ''}'.trim().isNotEmpty ? '${u['full_name']}' : '${u['username'] ?? ''}';
    loaded = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- polling
  void startPolling() {
    _polling = true;
    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) => _tick());
  }

  void stopPolling() {
    _polling = false;
    _timer?.cancel();
    _timer = null;
  }

  void pause() => _timer?.cancel();

  void resume() {
    if (!_polling) return;
    startPolling();
    _tick();
  }

  Future<void> _tick() async {
    if (_inflight) return;
    _inflight = true;
    try {
      await refresh();
    } catch (_) {/* mất mạng: giữ dữ liệu cũ, lượt sau thử lại */} finally {
      _inflight = false;
    }
  }

  void clear() {
    stopPolling();
    devices = [];
    notes = [];
    events = [];
    userName = userEmail = '';
    loaded = false;
    _busyIds.clear();
    _dismissed.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------- lệnh khóa
  Device? _byId(String id) {
    for (final d in devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _setBusy(String id, bool v) {
    v ? _busyIds.add(id) : _busyIds.remove(id);
    _byId(id)?.busy = v;
    notifyListeners();
  }

  /// Gửi LOCK/UNLOCK qua API (server publish MQTT tới khóa), rồi chờ khóa báo trạng thái mới.
  Future<void> send(Device d, String cmd) async {
    if (d.busy || !d.online) return;
    final target = cmd == 'LOCK' ? 'locked' : 'unlocked';
    _setBusy(d.id, true);
    try {
      final res = await api.request('POST', Endpoints.deviceCommand(d.id), body: {'command': cmd});
      var done = false;
      for (var i = 0; i < 8 && !done; i++) {
        await Future.delayed(const Duration(seconds: 1));
        await refresh(force: true);
        done = _byId(d.id)?.lock == target;
      }
      if (!done) toast('${d.name} chưa phản hồi. Kiểm tra lại sau ít giây.');
      else if (res['message'] is String) toast(res['message'] as String);
    } on ApiException catch (e) {
      toast(e.message);
    } finally {
      _setBusy(d.id, false);
    }
  }

  // ---------------------------------------------------------------- thông báo
  Future<void> _postRead(List<String> ids) =>
      api.request('POST', Endpoints.notificationsRead, body: {'ids': ids});

  Future<void> markRead(Note n) async {
    if (n.read) return;
    n.read = true;
    notifyListeners();
    try {
      await _postRead([n.id]);
    } on ApiException catch (e) {
      n.read = false;
      notifyListeners();
      toast(e.message);
    }
  }

  Future<void> readAll() async {
    final ids = notes.where((n) => !n.read).map((n) => n.id).toList();
    if (ids.isEmpty) return;
    for (final n in notes) {
      n.read = true;
    }
    notifyListeners();
    try {
      await _postRead(ids);
    } on ApiException catch (e) {
      toast(e.message);
      await refresh(force: true).catchError((_) {});
    }
  }

  void remove(Note n) {
    _dismissed.add(n.id);
    notes.remove(n);
    notifyListeners();
  }
}

final store = Store();
