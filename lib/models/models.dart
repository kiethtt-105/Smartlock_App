// Model cho dữ liệu JSON của API. Chỉ giữ các trường app cần dùng.

String _s(Map j, String k) => (j[k] ?? '').toString();
bool _b(Map j, String k) => j[k] == true;
int? _i(Map j, String k) => (j[k] as num?)?.toInt();
DateTime? _d(Map j, String k) {
  final v = j[k];
  return (v is String && v.isNotEmpty) ? DateTime.tryParse(v)?.toLocal() : null;
}

List<Map<String, dynamic>> asList(dynamic v) =>
    (v as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();

class AppUser {
  final String id, email, username, fullName, phone, initials;
  final bool twoFa;

  AppUser.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        email = _s(j, 'email'),
        username = _s(j, 'username'),
        fullName = _s(j, 'full_name'),
        phone = _s(j, 'phone'),
        initials = _s(j, 'initials'),
        twoFa = _b(j, 'two_fa_enabled');

  String get displayName => fullName.isNotEmpty ? fullName : username;
}

class LockDevice {
  final String id, name, deviceCode, status, statusDisplay, lockState, location, firmware, mac;
  final String ownerName;
  final int? battery;
  final DateTime? lastSeen;
  final bool wifi, bluetooth, nfc, isOwner;
  final List<String> permissions;

  LockDevice.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        name = _s(j, 'name'),
        deviceCode = _s(j, 'device_code'),
        status = _s(j, 'status'),
        statusDisplay = _s(j, 'status_display'),
        lockState = _s(j, 'lock_state'),
        location = _s(j, 'location'),
        firmware = _s(j, 'firmware_version'),
        mac = _s(j, 'mac_address'),
        ownerName = _s(j, 'owner_name'),
        battery = _i(j, 'battery_level'),
        lastSeen = _d(j, 'last_seen_at'),
        wifi = _b(j, 'wifi_enabled'),
        bluetooth = _b(j, 'bluetooth_enabled'),
        nfc = _b(j, 'nfc_enabled'),
        isOwner = _b(j, 'is_owner'),
        permissions = ((j['permissions'] as List?) ?? []).map((e) => e.toString()).toList();

  bool get isOnline => status == 'online';
  bool can(String code) => isOwner || permissions.contains(code);
}

class AccessEventInfo {
  final String id, deviceName, method, reason, who;
  final bool success;
  final DateTime? createdAt;

  AccessEventInfo.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        deviceName = _s(j, 'device_name'),
        method = _s(j, 'method'),
        reason = _s(j, 'reason'),
        who = _s(j, 'who'),
        success = _b(j, 'success'),
        createdAt = _d(j, 'created_at');

  String get methodLabel {
    switch (method) {
      case 'RFID':
        return 'Thẻ RFID';
      case 'PIN':
        return 'Mã PIN';
      case 'FACE':
        return 'Khuôn mặt';
      case 'BLE':
        return 'Bluetooth';
      case 'NFC_PHONE':
        return 'NFC điện thoại';
      case '':
        return 'Điều khiển từ xa';
      default:
        return method;
    }
  }
}

class LiveState {
  final bool connected, tamper, lockedOut;
  final int? secondsAgo, battery;
  final String lockState;
  final List<AccessEventInfo> events;

  LiveState.fromJson(Map<String, dynamic> j)
      : connected = _b(j, 'connected'),
        tamper = _b(j, 'tamper'),
        lockedOut = _b(j, 'locked_out'),
        secondsAgo = _i(j, 'seconds_ago'),
        battery = _i(j, 'battery'),
        lockState = _s(j, 'lock_state'),
        events = asList(j['events']).map(AccessEventInfo.fromJson).toList();
}

class CommandInfo {
  final String id, command, status;

  CommandInfo.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        command = _s(j, 'command'),
        status = _s(j, 'status');

  bool get isDone => const ['acknowledged', 'failed', 'expired'].contains(status);
}

class DoorPin {
  final String id, label, createdBy;
  final DateTime? expiresAt, createdAt;
  final int? maxUses;
  final int useCount;
  final bool isRevoked, isValidNow;

  DoorPin.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        label = _s(j, 'label'),
        createdBy = _s(j, 'created_by'),
        expiresAt = _d(j, 'expires_at'),
        createdAt = _d(j, 'created_at'),
        maxUses = _i(j, 'max_uses'),
        useCount = _i(j, 'use_count') ?? 0,
        isRevoked = _b(j, 'is_revoked'),
        isValidNow = _b(j, 'is_valid_now');
}

class CardDeviceLink {
  final String deviceId, deviceName;
  final bool isActive;

  CardDeviceLink.fromJson(Map<String, dynamic> j)
      : deviceId = _s(j, 'device_id'),
        deviceName = _s(j, 'device_name'),
        isActive = _b(j, 'is_active');
}

class CardInfo {
  final String id, name, owner;
  final bool isActive, isMine;
  final List<CardDeviceLink> devices;

  CardInfo.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        name = _s(j, 'name'),
        owner = _s(j, 'owner'),
        isActive = _b(j, 'is_active'),
        isMine = _b(j, 'is_mine'),
        devices = asList(j['devices']).map(CardDeviceLink.fromJson).toList();

  String get title => name.isNotEmpty ? name : 'Thẻ không tên';
}

class FaceProfileInfo {
  final String id, name, user;
  final bool isActive;

  FaceProfileInfo.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        name = _s(j, 'name'),
        user = _s(j, 'user'),
        isActive = _b(j, 'is_active');
}

class ShareInfo {
  final String id, deviceId, deviceName, username, fullName, sharedBy;
  final List<String> permissions;
  final DateTime? expiresAt;

  ShareInfo.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        deviceId = _s(j, 'device_id'),
        deviceName = _s(j, 'device_name'),
        username = _s((j['user'] as Map?) ?? {}, 'username'),
        fullName = _s((j['user'] as Map?) ?? {}, 'full_name'),
        sharedBy = _s(j, 'shared_by'),
        permissions = ((j['permissions'] as List?) ?? []).map((e) => e.toString()).toList(),
        expiresAt = _d(j, 'expires_at');

  String get who => fullName.isNotEmpty ? fullName : username;
}

class RolePreset {
  final String key, label, desc;

  RolePreset.fromJson(Map<String, dynamic> j)
      : key = _s(j, 'key'),
        label = _s(j, 'label'),
        desc = _s(j, 'desc');
}

class NotificationInfo {
  final String id, title, message, severity, type;
  final bool isRead;
  final DateTime? createdAt;

  NotificationInfo.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        title = _s(j, 'title'),
        message = _s(j, 'message'),
        severity = _s(j, 'severity'),
        type = _s(j, 'type'),
        isRead = _b(j, 'is_read'),
        createdAt = _d(j, 'created_at');
}

class AuditInfo {
  final String id, action, severity, device, ip;
  final bool success;
  final DateTime? createdAt;

  AuditInfo.fromJson(Map<String, dynamic> j)
      : id = _s(j, 'id'),
        action = _s(j, 'action'),
        severity = _s(j, 'severity'),
        device = _s(j, 'device'),
        ip = _s(j, 'ip_address'),
        success = _b(j, 'success'),
        createdAt = _d(j, 'created_at');
}

class StatusLogInfo {
  final String lockState;
  final int? battery, signal;
  final bool tamper;
  final DateTime? at;

  StatusLogInfo.fromJson(Map<String, dynamic> j)
      : lockState = _s(j, 'lock_state'),
        battery = _i(j, 'battery_level'),
        signal = _i(j, 'signal_strength'),
        tamper = _b(j, 'tamper_detected'),
        at = _d(j, 'recorded_at');
}

class PageResult<T> {
  final List<T> items;
  final int page;
  final bool hasNext;
  final int total;
  final int unreadCount;

  PageResult(this.items, this.page, this.hasNext, this.total, [this.unreadCount = 0]);

  factory PageResult.from(Map<String, dynamic> j, T Function(Map<String, dynamic>) f) =>
      PageResult(asList(j['items']).map(f).toList(), _i(j, 'page') ?? 1, _b(j, 'has_next'),
          _i(j, 'total') ?? 0, _i(j, 'unread_count') ?? 0);
}
