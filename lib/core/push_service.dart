import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_client.dart';
import 'store.dart';
import 'toast.dart';

/// Push FCM. Server (services.send_notification_push) gửi tới FCM token lưu trong phiên đăng nhập.
/// Nếu Firebase chưa cấu hình (thiếu google-services.json) thì tự tắt, app vẫn chạy bình thường.
class PushService {
  bool _ready = false;

  /// Gọi khi người dùng chạm vào thông báo (mở app từ nền) -> main.dart đặt thành "đi tới /notifications".
  void Function()? onOpen;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n != null) toast('${n.title ?? ''}${n.body == null ? '' : ': ${n.body}'}');
        store.refresh(force: true).catchError((_) {}); // app đang mở: cập nhật ngay
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpen?.call());
      m.onTokenRefresh.listen(_send);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Gọi sau khi đăng nhập: đưa FCM token của máy này lên phiên hiện tại.
  Future<void> register() async {
    if (!_ready) return;
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _send(t);
    } catch (_) {}
  }

  /// Gọi trước khi đăng xuất để server ngừng gửi push tới máy này.
  Future<void> unregister() async {
    if (!_ready || !api.hasToken) return;
    try {
      await api.request('DELETE', Endpoints.pushToken);
    } catch (_) {}
  }

  Future<void> _send(String token) async {
    if (!api.hasToken) return;
    try {
      await api.request('PUT', Endpoints.pushToken, body: {'fcm_token': token, 'push_enabled': true});
    } catch (_) {}
  }
}

final push = PushService();
