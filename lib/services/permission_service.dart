import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Một nhóm quyền hiển thị trên màn hình xin quyền.
class AppPermission {
  final String title;
  final String description;
  final IconData icon;
  final List<Permission> perms;

  /// true: chỉ cần 1 trong các quyền là đủ (vd. ảnh/bộ nhớ khác nhau theo bản Android).
  final bool anyOf;

  /// true: quyền cấp lúc cài app, không hỏi lúc chạy (NFC).
  final bool installTime;

  const AppPermission({
    required this.title,
    required this.description,
    required this.icon,
    this.perms = const [],
    this.anyOf = false,
    this.installTime = false,
  });
}

class PermissionService {
  static const items = <AppPermission>[
    AppPermission(
      title: 'Bluetooth',
      description: 'Tìm và kết nối khóa qua BLE để mở khóa gần.',
      icon: Icons.bluetooth,
      perms: [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
      ],
    ),
    AppPermission(
      title: 'Vị trí',
      description: 'Android yêu cầu để quét Bluetooth/Wi-Fi và đọc tên Wi-Fi.',
      icon: Icons.location_on_outlined,
      perms: [Permission.locationWhenInUse],
    ),
    AppPermission(
      title: 'Wi-Fi lân cận',
      description: 'Cấu hình Wi-Fi cho khóa (Android 13 trở lên).',
      icon: Icons.wifi,
      perms: [Permission.nearbyWifiDevices],
    ),
    AppPermission(
      title: 'Camera',
      description: 'Đăng ký khuôn mặt và quét mã QR thêm khóa.',
      icon: Icons.photo_camera_outlined,
      perms: [Permission.camera],
    ),
    AppPermission(
      title: 'Ảnh và bộ nhớ',
      description: 'Chọn ảnh đại diện, xuất dữ liệu cá nhân.',
      icon: Icons.folder_outlined,
      perms: [Permission.photos, Permission.storage],
      anyOf: true,
    ),
    AppPermission(
      title: 'Thông báo',
      description: 'Nhận cảnh báo mở khóa, pin yếu, chia sẻ khóa.',
      icon: Icons.notifications_none,
      perms: [Permission.notification],
    ),
    AppPermission(
      title: 'NFC',
      description: 'Đọc thẻ NFC. Quyền tự cấp khi cài, nhớ bật NFC trong Cài đặt máy.',
      icon: Icons.nfc,
      installTime: true,
    ),
  ];

  static bool _ok(PermissionStatus s) => s.isGranted || s.isLimited;

  static Future<bool> isGranted(AppPermission p) async {
    if (p.perms.isEmpty) return true;
    final statuses = <PermissionStatus>[];
    for (final x in p.perms) {
      statuses.add(await x.status);
    }
    return p.anyOf ? statuses.any(_ok) : statuses.every(_ok);
  }

  /// Bị từ chối vĩnh viễn: chỉ còn cách mở Cài đặt hệ thống.
  static Future<bool> isPermanentlyDenied(AppPermission p) async {
    if (await isGranted(p)) return false;
    for (final x in p.perms) {
      if (await x.isPermanentlyDenied) return true;
    }
    return false;
  }

  /// Xin lần lượt từng quyền (không xin song song để hộp thoại không chồng nhau).
  static Future<void> request(AppPermission p) async {
    for (final x in p.perms) {
      if (p.anyOf && await isGranted(p)) break;
      if (!await x.isGranted) await x.request();
    }
  }

  static Future<bool> allGranted() async {
    for (final p in items) {
      if (!await isGranted(p)) return false;
    }
    return true;
  }
}
