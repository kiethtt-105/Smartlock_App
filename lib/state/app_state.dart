import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/smartlock_api.dart';
import '../models/models.dart';

/// Trạng thái dùng chung: người dùng đang đăng nhập + danh sách khóa.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  AppUser? user;
  List<LockDevice> devices = [];
  int unread = 0;
  bool loadingDevices = false;
  String? devicesError;

  /// Đọc token đã lưu. true = có phiên để thử dùng tiếp.
  Future<bool> restore() async {
    await ApiClient.instance.loadTokens();
    return ApiClient.instance.hasSession;
  }

  Future<void> onLogin(Map<String, dynamic> j) async {
    await ApiClient.instance.setTokens(j);
    user = AppUser.fromJson((j['user'] as Map).cast<String, dynamic>());
    notifyListeners();
  }

  Future<void> refreshUser() async {
    user = await SmartlockApi.me();
    notifyListeners();
  }

  /// [silent] = true: không bật vòng loading (dùng cho tự làm mới định kỳ).
  Future<void> refreshDevices({bool silent = false}) async {
    if (!silent) {
      loadingDevices = true;
      devicesError = null;
      notifyListeners();
    }
    try {
      devices = await SmartlockApi.devices();
      devicesError = null;
    } on ApiException catch (e) {
      if (!silent) devicesError = e.message;
    } finally {
      loadingDevices = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnread() async {
    try {
      unread = await SmartlockApi.unreadCount();
      notifyListeners();
    } on ApiException {
      // bỏ qua, lần sau thử lại
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshDevices(),
      refreshUnread(),
      if (user == null) refreshUser().catchError((_) {}),
    ]);
  }

  Future<void> logout() async {
    try {
      await SmartlockApi.logout();
    } catch (_) {
      // dù server không trả lời vẫn xóa phiên trên máy
    }
    clear();
    await ApiClient.instance.clearTokens();
  }

  void clear() {
    user = null;
    devices = [];
    unread = 0;
    notifyListeners();
  }
}
