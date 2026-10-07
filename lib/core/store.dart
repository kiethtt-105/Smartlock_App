import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'toast.dart';

DateTime _dt(dynamic v) => (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? DateTime.now();

class Device {
  final String id, name, code;
  final bool online, tamper, lockedOut, isOwner, wifi, bluetooth, nfc;
  final String location, firmware;
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
    this.bluetooth = true,
    this.nfc = true,
    this.location = '',
    this.firmware = '',
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
        bluetooth: j['bluetooth_enabled'] != false,
        nfc: j['nfc_enabled'] != false,
        location: '${j['location'] ?? ''}',
        firmware: '${j['firmware_version'] ?? ''}',
        permissions: ((j['permissions'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  bool _can(String p) => online && wifi && (isOwner || permissions.contains(p));
  bool can(String p) => isOwner || permissions.contains(p);
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

class AuditEntry {
  final String action, device;
  final bool success;
  final String severity;
  final DateTime at;
  AuditEntry(this.action, this.device, this.success, this.severity, this.at);

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry('${j['action'] ?? ''}', '${j['device'] ?? ''}',
      j['success'] != false, '${j['severity'] ?? 'info'}', _dt(j['created_at']));
}

class SessionItem {
  final String id, name, platform;
  final DateTime? lastUsed;
  final bool current;
  SessionItem.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = '${j['device_name'] ?? ''}'.isEmpty ? 'Thiết bị không tên' : '${j['device_name']}',
        platform = '${j['platform'] ?? ''}',
        lastUsed = _dtn(j['last_used_at']),
        current = j['is_current'] == true;
}

class Security {
  final bool enabled, totp, emailOtp;
  final int passkeys;
  final List<SessionItem> sessions;
  const Security({this.enabled = false, this.totp = false, this.emailOtp = false, this.passkeys = 0, this.sessions = const []});

  factory Security.fromJson(Map<String, dynamic> j) => Security(
        enabled: j['two_fa_enabled'] == true,
        totp: j['totp'] == true,
        emailOtp: j['email_otp'] == true,
        passkeys: ((j['passkeys'] as List?) ?? const []).length,
        sessions: ((j['sessions'] as List?) ?? const []).whereType<Map>().map((e) => SessionItem.fromJson(e.cast<String, dynamic>())).toList(),
      );
}

DateTime? _dtn(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

class Pin {
  final String id, deviceId, label;
  final DateTime? expiresAt;
  final int maxUses, useCount;
  final bool validNow, revoked;
  Pin.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        deviceId = '${j['device_id']}',
        label = '${j['label'] ?? ''}',
        expiresAt = _dtn(j['expires_at']),
        maxUses = (j['max_uses'] as num?)?.toInt() ?? 0,
        useCount = (j['use_count'] as num?)?.toInt() ?? 0,
        validNow = j['is_valid_now'] == true,
        revoked = j['is_revoked'] == true;
}

class CardItem {
  final String id, name, owner;
  final bool active, mine;
  final List<String> devices;
  CardItem.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = '${j['name'] ?? ''}'.isEmpty ? 'Thẻ không tên' : '${j['name']}',
        owner = '${j['owner'] ?? ''}',
        active = j['is_active'] == true,
        mine = j['is_mine'] == true,
        devices = ((j['devices'] as List?) ?? const []).whereType<Map>().map((e) => '${e['device_name']}').toList();
}

class FaceItem {
  final String id, deviceId, name, user;
  final bool active;
  FaceItem.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        deviceId = '${j['device_id']}',
        name = '${j['name'] ?? ''}',
        user = '${j['user'] ?? ''}',
        active = j['is_active'] == true;
}

class ShareItem {
  final String id, deviceId, deviceName, who, sharedBy;
  final List<String> permissions;
  final DateTime? expiresAt;
  ShareItem.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        deviceId = '${j['device_id']}',
        deviceName = '${j['device_name'] ?? ''}',
        who = (j['user'] is Map)
            ? ('${(j['user'] as Map)['full_name'] ?? ''}'.isNotEmpty
                ? '${(j['user'] as Map)['full_name']}'
                : '${(j['user'] as Map)['username'] ?? ''}')
            : '',
        sharedBy = '${j['shared_by'] ?? ''}',
        permissions = ((j['permissions'] as List?) ?? const []).map((e) => '$e').toList(),
        expiresAt = _dtn(j['expires_at']);
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
  List<AuditEntry> audit = [];
  Security security = const Security();
  List<Pin> pins = [];
  List<CardItem> cards = [];
  List<FaceItem> faces = [];
  List<ShareItem> sharesOut = [], sharesIn = [];
  int get cardCount => cards.length;
  int get pinCount => pins.where((p) => p.validNow).length;
  int get faceCount => faces.length;
  int get shareCount => sharesOut.length;
  String userName = '', userEmail = '';
  bool loaded = false;

  final _busyIds = <String>{};
  final _dismissed = <String>{}; // ẩn ngay trong lúc chờ server xoá
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
    audit = list('audit').map(AuditEntry.fromJson).toList();
    final sec = b['security'];
    if (sec is Map) security = Security.fromJson(sec.cast<String, dynamic>());
    cards = list('cards').map(CardItem.fromJson).toList();
    pins = list('pins').map(Pin.fromJson).toList();
    faces = list('faces').map(FaceItem.fromJson).toList();
    sharesOut = list('shares_out').map(ShareItem.fromJson).toList();
    sharesIn = list('shares_in').map(ShareItem.fromJson).toList();
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
    audit = [];
    security = const Security();
    pins = [];
    cards = [];
    faces = [];
    sharesOut = [];
    sharesIn = [];
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
      if (!done) {
        toast('${d.name} chưa phản hồi. Kiểm tra lại sau ít giây.');
      } else if (res['message'] is String) {
        toast(res['message'] as String);
      }
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

  /// Xoá thông báo trên server (DELETE /notifications/{id}/); lỗi thì khôi phục lại.
  Future<void> remove(Note n) async {
    final i = notes.indexOf(n);
    _dismissed.add(n.id);
    notes.remove(n);
    notifyListeners();
    try {
      await api.request('DELETE', Endpoints.notificationDelete(n.id));
    } on ApiException catch (e) {
      if (e.status == 404) return; // đã bị xoá ở nơi khác
      _dismissed.remove(n.id);
      notes.insert(i < 0 ? 0 : i, n);
      notifyListeners();
      toast(e.message);
    }
  }

  Future<void> changePassword(String oldPw, String newPw) =>
      api.request('POST', Endpoints.changePassword, body: {'old_password': oldPw, 'new_password': newPw});
}

extension StoreActions on Store {
  Future<void> updateDevice(String id, Map<String, dynamic> body) => _do('PATCH', Endpoints.device(id), body: body);

  Future<void> reboot(Device d) async {
    final r = await api.request('POST', Endpoints.deviceCommand(d.id), body: {'command': 'REBOOT'});
    toast('${r['message'] ?? 'Đã gửi lệnh khởi động lại.'}');
  }

  Future<void> updateProfile(String fullName, String phone) =>
      _do('PATCH', Endpoints.me, body: {'full_name': fullName, 'phone': phone});

  Future<void> revokeSession(SessionItem s) => _do('DELETE', Endpoints.sessionRevoke(s.id));

  Future<Map<String, dynamic>> totpBegin() => api.request('POST', Endpoints.twoFaTotpBegin, body: {});
  Future<void> totpConfirm(String setupToken, String code) =>
      _do('POST', Endpoints.twoFaTotpConfirm, body: {'setup_token': setupToken, 'code': code});
  Future<void> emailOtpSend() => api.request('POST', Endpoints.twoFaEmailSetupSend, body: {});
  Future<void> emailOtpConfirm(String code) => _do('POST', Endpoints.twoFaEmailSetupConfirm, body: {'code': code});
  Future<void> removeTwoFa(String method, String password) =>
      _do('POST', Endpoints.twoFaRemove(method), body: {'password': password});

  Future<Map<String, dynamic>> _do(String m, String path, {Map<String, dynamic>? body}) async {
    final r = await api.request(m, path, body: body);
    await refresh(force: true).catchError((_) {});
    return r;
  }

  Future<void> claimDevice(String code, String secret) =>
      _do('POST', Endpoints.deviceClaim, body: {'device_code': code, 'secret': secret});

  /// Trả mã PIN dạng thô - server chỉ cho xem đúng 1 lần.
  Future<String> createPin(String deviceId, {String label = '', int ttlMinutes = 1440, int maxUses = 1}) async {
    final r = await _do('POST', Endpoints.devicePins(deviceId),
        body: {'label': label, 'ttl_minutes': ttlMinutes, 'max_uses': maxUses});
    return '${r['plain_pin']}';
  }

  Future<void> revokePin(Pin p) => _do('DELETE', Endpoints.pin(p.id));

  Future<void> addCard(String deviceId, String uid, String name) =>
      _do('POST', Endpoints.deviceCards(deviceId), body: {'uid': uid, 'name': name});
  Future<void> setCardActive(CardItem c, bool v) => _do('PATCH', Endpoints.card(c.id), body: {'is_active': v});
  Future<void> deleteCard(CardItem c) => _do('DELETE', Endpoints.card(c.id));

  Future<void> setFaceActive(FaceItem f, bool v) => _do('PATCH', Endpoints.face(f.id), body: {'is_active': v});
  Future<void> deleteFace(FaceItem f) => _do('DELETE', Endpoints.face(f.id));

  Future<void> shareDevice(String deviceId, String identifier, String preset) =>
      _do('POST', Endpoints.deviceShares(deviceId), body: {'identifier': identifier, 'preset': preset});
  Future<void> revokeShare(ShareItem s) => _do('DELETE', Endpoints.share(s.id));
  Future<void> leaveShare(ShareItem s) => _do('POST', Endpoints.shareLeave(s.id), body: {});
}

final store = Store();
