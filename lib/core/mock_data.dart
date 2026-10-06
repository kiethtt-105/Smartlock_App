import 'package:flutter/foundation.dart';

class Device {
  final String id, name, code;
  final bool online, tamper, lockedOut;
  final int battery;
  String lock; // locked | unlocked | jammed | unknown
  Device({required this.id, required this.name, required this.code, required this.online,
      required this.battery, required this.lock, this.tamper = false, this.lockedOut = false});
}

class Note {
  final String id, sev, title, body; // sev: info | warning | critical
  final DateTime at;
  bool read;
  Note(this.id, this.sev, this.title, this.body, this.at, {this.read = false});
}

class AccessEvent {
  final String method, who, reason;
  final bool success;
  final DateTime at;
  AccessEvent(this.method, this.who, this.success, this.at, {this.reason = ''});
}

DateTime _ago(int min) => DateTime.now().subtract(Duration(minutes: min));

final mockDevices = <Device>[
  Device(id: 'door-1', name: 'Cửa chính', code: 'SL-A1B2C3', online: true, battery: 86, lock: 'locked'),
  Device(id: 'door-2', name: 'Cửa phòng ngủ', code: 'SL-D4E5F6', online: false, battery: 18, lock: 'unknown'),
  Device(id: 'door-3', name: 'Cổng garage', code: 'SL-77AA10', online: true, battery: 54,
      lock: 'unlocked', tamper: true),
];

final mockNotes = <Note>[
  Note('1', 'critical', 'Cảnh báo phá khóa', 'Cổng garage phát hiện rung động bất thường.', _ago(3)),
  Note('2', 'warning', 'Pin yếu', 'Cửa phòng ngủ còn 18% pin.', _ago(45)),
  Note('3', 'info', 'Có người mở cửa', 'Cửa chính được mở bằng thẻ NFC.', _ago(120), read: true),
  Note('4', 'info', 'Đã thêm phương thức 2FA', 'Google Authenticator vừa được thêm.', _ago(60 * 26), read: true),
];

final mockEvents = <AccessEvent>[
  AccessEvent('NFC', 'Thẻ của Bố', true, _ago(8)),
  AccessEvent('PIN', 'Mã khách', false, _ago(70), reason: 'Sai mã'),
  AccessEvent('FACE', 'Mẹ', true, _ago(190)),
  AccessEvent('APP', 'Bạn', true, _ago(60 * 5)),
];

final unreadCount = ValueNotifier<int>(mockNotes.where((n) => !n.read).length);

String ago(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'vừa xong';
  if (m < 60) return '$m phút trước';
  if (m < 60 * 24) return '${m ~/ 60} giờ trước';
  return '${m ~/ (60 * 24)} ngày trước';
}