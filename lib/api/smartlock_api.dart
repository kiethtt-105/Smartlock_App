import '../models/models.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Tất cả lệnh gọi API của app (đường dẫn tương đối /api/app/...).
class SmartlockApi {
  static final ApiClient _c = ApiClient.instance;

  // ───────────── xác thực ─────────────

  static Future<Map<String, dynamic>> login(String identifier, String password) =>
      _c.post('/auth/login/', auth: false, body: {
        'identifier': identifier,
        'password': password,
        'platform': 'android',
        'device_name': 'Android',
        'app_version': ApiConfig.appVersion,
      });

  static Future<void> twoFactorEmailSend(String challenge) =>
      _c.post('/auth/2fa/email/send/', auth: false, body: {'challenge_token': challenge});

  static Future<Map<String, dynamic>> twoFactorVerify(
          String challenge, String method, String code) =>
      _c.post('/auth/2fa/verify/',
          auth: false,
          body: {'challenge_token': challenge, 'method': method, 'code': code});

  static Future<String> register({
    required String email,
    required String username,
    required String fullName,
    required String password,
  }) async {
    final j = await _c.post('/auth/register/', auth: false, body: {
      'email': email,
      'username': username,
      'full_name': fullName,
      'password': password,
    });
    return (j['message'] ?? 'Đã tạo tài khoản.').toString();
  }

  static Future<void> resendVerification(String email) =>
      _c.post('/auth/resend-verification/', auth: false, body: {'email': email});

  static Future<String> passwordReset(String email) async {
    final j = await _c.post('/auth/password-reset/', auth: false, body: {'email': email});
    return (j['message'] ?? 'Đã gửi yêu cầu.').toString();
  }

  static Future<void> logout() => _c.post('/auth/logout/', body: {});

  // ───────────── tài khoản ─────────────

  static Future<AppUser> me() async =>
      AppUser.fromJson(((await _c.get('/me/'))['user'] as Map).cast<String, dynamic>());

  static Future<AppUser> updateProfile({String? fullName, String? phone}) async {
    final j = await _c.patch('/me/', body: {
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
    });
    return AppUser.fromJson((j['user'] as Map).cast<String, dynamic>());
  }

  static Future<void> changePassword(String oldPw, String newPw) =>
      _c.post('/me/password/', body: {'old_password': oldPw, 'new_password': newPw});

  static Future<void> deleteAccount(String password) =>
      _c.delete('/me/', body: {'password': password});

  static Future<void> setPush(bool enabled) =>
      _c.put('/me/push-token/', body: {'push_enabled': enabled});

  static Future<void> revokeOtherSessions() => _c.delete('/me/sessions/');

  // ───────────── khóa ─────────────

  static Future<List<LockDevice>> devices() async =>
      asList((await _c.get('/devices/'))['devices']).map(LockDevice.fromJson).toList();

  static Future<LockDevice> device(String id) async => LockDevice.fromJson(
      ((await _c.get('/devices/$id/'))['device'] as Map).cast<String, dynamic>());

  static Future<LiveState> live(String id) async =>
      LiveState.fromJson(await _c.get('/devices/$id/live/'));

  static Future<LockDevice> claim(String code, String secret) async {
    final j = await _c.post('/devices/claim/', body: {'device_code': code, 'secret': secret});
    return LockDevice.fromJson((j['device'] as Map).cast<String, dynamic>());
  }

  static Future<void> updateDevice(String id,
          {String? name, String? location, bool? wifi, bool? bluetooth, bool? nfc}) =>
      _c.patch('/devices/$id/', body: {
        if (name != null) 'name': name,
        if (location != null) 'location': location,
        if (wifi != null) 'wifi_enabled': wifi,
        if (bluetooth != null) 'bluetooth_enabled': bluetooth,
        if (nfc != null) 'nfc_enabled': nfc,
      });

  static Future<void> releaseDevice(String id, String deviceCode) =>
      _c.delete('/devices/$id/', body: {'device_code': deviceCode});

  static Future<CommandInfo> sendCommand(String id, String command) async {
    final j = await _c.post('/devices/$id/commands/', body: {'command': command});
    return CommandInfo.fromJson((j['command'] as Map).cast<String, dynamic>());
  }

  static Future<CommandInfo> commandStatus(String commandId) async {
    final j = await _c.get('/commands/$commandId/');
    return CommandInfo.fromJson((j['command'] as Map).cast<String, dynamic>());
  }

  static Future<void> clearLockout(String id) => _c.post('/devices/$id/clear-lockout/');

  static Future<PageResult<StatusLogInfo>> statusHistory(String id,
          {int hours = 24, int page = 1}) async =>
      PageResult.from(
          await _c.get('/devices/$id/status-history/',
              query: {'hours': hours, 'page': page}),
          StatusLogInfo.fromJson);

  // ───────────── PIN ─────────────

  static Future<List<DoorPin>> pins(String deviceId) async =>
      asList((await _c.get('/devices/$deviceId/pins/'))['pins']).map(DoorPin.fromJson).toList();

  /// Trả (pin, mã PIN thô). Mã thô chỉ trả đúng 1 lần.
  static Future<(DoorPin, String)> createPin(String deviceId,
      {required String label, required int ttlMinutes, required int maxUses}) async {
    final j = await _c.post('/devices/$deviceId/pins/',
        body: {'label': label, 'ttl_minutes': ttlMinutes, 'max_uses': maxUses});
    return (
      DoorPin.fromJson((j['pin'] as Map).cast<String, dynamic>()),
      (j['plain_pin'] ?? '').toString()
    );
  }

  static Future<void> revokePin(String pinId) => _c.delete('/pins/$pinId/');

  // ───────────── thẻ NFC ─────────────

  static Future<List<CardInfo>> cards() async =>
      asList((await _c.get('/cards/'))['cards']).map(CardInfo.fromJson).toList();

  static Future<void> renameCard(String id, String name) =>
      _c.patch('/cards/$id/', body: {'name': name});

  static Future<void> setCardActive(String id, bool active) =>
      _c.patch('/cards/$id/', body: {'is_active': active});

  static Future<void> setCardLinkActive(String cardId, String deviceId, bool active) =>
      _c.patch('/cards/$cardId/devices/$deviceId/', body: {'is_active': active});

  static Future<void> deleteCard(String id) => _c.delete('/cards/$id/');

  static Future<Map<String, dynamic>> enrollStart(String deviceId) async =>
      ((await _c.post('/devices/$deviceId/cards/enroll/'))['enroll'] as Map)
          .cast<String, dynamic>();

  static Future<Map<String, dynamic>> enrollPoll(String deviceId, String since) async =>
      ((await _c.get('/devices/$deviceId/cards/enroll/', query: {'since': since}))['enroll']
              as Map)
          .cast<String, dynamic>();

  static Future<void> enrollCancel(String deviceId) =>
      _c.delete('/devices/$deviceId/cards/enroll/');

  static Future<void> registerCardUid(String deviceId, String uid, String name) =>
      _c.post('/devices/$deviceId/cards/', body: {'uid': uid, 'name': name});

  // ───────────── khuôn mặt ─────────────

  static Future<List<FaceProfileInfo>> faces(String deviceId) async =>
      asList((await _c.get('/devices/$deviceId/faces/'))['profiles'])
          .map(FaceProfileInfo.fromJson)
          .toList();

  static Future<void> setFaceActive(String id, bool active) =>
      _c.patch('/faces/$id/', body: {'is_active': active});

  static Future<void> deleteFace(String id) => _c.delete('/faces/$id/');

  // ───────────── chia sẻ ─────────────

  static Future<List<RolePreset>> presets() async =>
      asList((await _c.get('/permissions/'))['role_presets']).map(RolePreset.fromJson).toList();

  static Future<List<ShareInfo>> deviceShares(String deviceId) async =>
      asList((await _c.get('/devices/$deviceId/shares/'))['shares'])
          .map(ShareInfo.fromJson)
          .toList();

  static Future<void> shareDevice(String deviceId,
          {required String identifier, required String preset, String? expiresAtIso}) =>
      _c.post('/devices/$deviceId/shares/', body: {
        'identifier': identifier,
        'preset': preset,
        if (expiresAtIso != null) 'expires_at': expiresAtIso,
      });

  static Future<void> revokeShare(String shareId) => _c.delete('/shares/$shareId/');

  static Future<List<ShareInfo>> incomingShares() async =>
      asList((await _c.get('/shares/incoming/'))['shares']).map(ShareInfo.fromJson).toList();

  static Future<void> leaveShare(String shareId) => _c.post('/shares/$shareId/leave/');

  // ───────────── lịch sử · thông báo ─────────────

  static Future<PageResult<AccessEventInfo>> history({String? deviceId, int page = 1}) async =>
      PageResult.from(
          await _c.get('/history/', query: {'page': page, if (deviceId != null) 'device': deviceId}),
          AccessEventInfo.fromJson);

  static Future<PageResult<AuditInfo>> audit({int page = 1}) async =>
      PageResult.from(await _c.get('/audit/', query: {'page': page}), AuditInfo.fromJson);

  static Future<PageResult<NotificationInfo>> notifications({int page = 1}) async =>
      PageResult.from(await _c.get('/notifications/', query: {'page': page}),
          NotificationInfo.fromJson);

  static Future<int> unreadCount() async =>
      ((await _c.get('/notifications/', query: {'unread': 1, 'page_size': 1}))['unread_count']
              as num?)
          ?.toInt() ??
      0;

  static Future<void> markAllRead() => _c.post('/notifications/read/', body: {'all': true});

  static Future<void> markRead(String id) =>
      _c.post('/notifications/read/', body: {'ids': [id]});

  static Future<void> deleteNotification(String id) => _c.delete('/notifications/$id/');

  static Future<void> clearReadNotifications() => _c.delete('/notifications/');
}
