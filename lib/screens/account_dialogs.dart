import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/toast.dart';

/// Hộp thoại nhập liệu dùng chung: chạy [submit], hiện lỗi từ server, đóng khi thành công.
Future<void> showForm(
  BuildContext context, {
  required String title,
  required String action,
  required List<(String label, bool secret, TextInputType? type)> fields,
  required Future<String?> Function(List<String> v) submit,
  String? info,
  List<String>? initial,
}) async {
  final ctrls = [for (int i = 0; i < fields.length; i++) TextEditingController(text: initial != null && i < initial.length ? initial[i] : '')];
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (info != null) SelectableText(info, style: t(13, color: C.sub)),
            for (int i = 0; i < fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: ctrls[i],
                  obscureText: fields[i].$2,
                  keyboardType: fields[i].$3,
                  decoration: InputDecoration(labelText: fields[i].$1),
                ),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Huỷ')),
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    setS(() => busy = true);
                    try {
                      final msg = await submit([for (final c in ctrls) c.text.trim()]);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (msg != null) toast(msg);
                    } on ApiException catch (e) {
                      toast(e.message);
                    } catch (_) {
                      toast('Đã có lỗi xảy ra, vui lòng thử lại.');
                    }
                    if (ctx.mounted) setS(() => busy = false);
                  },
            child: Text(busy ? 'Đang gửi…' : action),
          ),
        ],
      ),
    ),
  );
  for (final c in ctrls) {
    c.dispose();
  }
}

Future<void> showForgotPassword(BuildContext context) => showForm(context,
    title: 'Quên mật khẩu',
    action: 'Gửi',
    fields: [('Email', false, TextInputType.emailAddress)],
    submit: (v) async {
      if (v[0].isEmpty) throw ApiException('Nhập email.');
      return auth.forgotPassword(v[0]);
    });

Future<void> showRegister(BuildContext context) => showForm(context,
    title: 'Đăng ký',
    action: 'Đăng ký',
    fields: [
      ('Họ tên', false, null),
      ('Tên đăng nhập', false, null),
      ('Email', false, TextInputType.emailAddress),
      ('Mật khẩu', true, null),
    ],
    submit: (v) async {
      if (v[1].isEmpty || v[2].isEmpty || v[3].isEmpty) throw ApiException('Nhập đủ tên đăng nhập, email và mật khẩu.');
      return auth.register(fullName: v[0], username: v[1], email: v[2], password: v[3]);
    });

Future<void> showChangePassword(BuildContext context) => showForm(context,
    title: 'Đổi mật khẩu',
    action: 'Đổi',
    fields: [('Mật khẩu hiện tại', true, null), ('Mật khẩu mới', true, null)],
    submit: (v) async {
      if (v[0].isEmpty || v[1].isEmpty) throw ApiException('Nhập mật khẩu hiện tại và mật khẩu mới.');
      await store.changePassword(v[0], v[1]);
      return 'Đã đổi mật khẩu. Các thiết bị khác sẽ bị đăng xuất.';
    });

/// Nhật ký hệ thống (lấy từ snapshot.audit).
void showAuditLog(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card2,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .75,
      builder: (_, ctrl) => ListenableBuilder(
        listenable: store,
        builder: (_, _) => store.audit.isEmpty
            ? Center(child: Text('Chưa có nhật ký.', style: t(14, color: C.sub)))
            : ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                itemCount: store.audit.length,
                separatorBuilder: (_, _) => const Divider(color: C.stroke),
                itemBuilder: (_, i) {
                  final a = store.audit[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(a.success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                        color: a.success ? C.green : C.red),
                    title: Text(a.action, style: t(14, w: FontWeight.w600)),
                    subtitle: Text('${a.device.isEmpty ? '—' : a.device} · ${ago(a.at)}', style: t(12.5, color: C.sub)),
                  );
                },
              ),
      ),
    ),
  );
}

Future<void> showClaimDevice(BuildContext context) => showForm(context,
    title: 'Thêm thiết bị',
    action: 'Thêm',
    fields: [('Mã thiết bị (vd SL-A1B2C3)', false, null), ('Secret in trên khóa', true, null)],
    submit: (v) async {
      if (v[0].isEmpty || v[1].isEmpty) throw ApiException('Nhập mã thiết bị và secret.');
      await store.claimDevice(v[0], v[1]);
      return 'Đã thêm khóa vào tài khoản.';
    });

Future<void> showEditProfile(BuildContext context) => showForm(context,
    title: 'Thông tin cá nhân',
    action: 'Lưu',
    initial: [store.userName, ''],
    fields: [('Họ tên', false, null), ('Số điện thoại', false, TextInputType.phone)],
    submit: (v) async {
      await store.updateProfile(v[0], v[1]);
      return 'Đã lưu thông tin.';
    });

/// Thiết lập / gỡ một phương thức 2FA. [method] = 'totp' | 'email'.
Future<void> showTwoFa(BuildContext context, String method, bool enabled) async {
  if (enabled) {
    return showForm(context,
        title: 'Gỡ xác thực',
        action: 'Gỡ',
        info: 'Nhập mật khẩu để xác nhận. Bạn không gỡ được phương thức cuối cùng khi 2FA đang bật.',
        fields: [('Mật khẩu', true, null)],
        submit: (v) async {
          await store.removeTwoFa(method, v[0]);
          return 'Đã gỡ phương thức xác thực.';
        });
  }
  try {
    if (method == 'totp') {
      final d = await store.totpBegin();
      if (!context.mounted) return;
      await showForm(context,
          title: 'Google Authenticator',
          action: 'Xác nhận',
          info: 'Mở Google Authenticator > Nhập khóa thiết lập, dán khóa này (không phân biệt khoảng trắng):\n\n${d['secret']}\n\nRồi nhập mã 6 số bên dưới.',
          fields: [('Mã 6 số', false, TextInputType.number)],
          submit: (v) async {
            await store.totpConfirm('${d['setup_token']}', v[0]);
            return 'Đã bật Google Authenticator.';
          });
    } else {
      await store.emailOtpSend();
      if (!context.mounted) return;
      await showForm(context,
          title: 'Mã qua email',
          action: 'Xác nhận',
          info: 'Mã xác nhận đã được gửi tới email của bạn.',
          fields: [('Mã 6 số', false, TextInputType.number)],
          submit: (v) async {
            await store.emailOtpConfirm(v[0]);
            return 'Đã bật mã qua email.';
          });
    }
  } on ApiException catch (e) {
    toast(e.message);
  }
}

/// Các thiết bị đang đăng nhập (từ snapshot.security.sessions).
void showSessions(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: C.card2,
    builder: (ctx) => ListenableBuilder(
      listenable: store,
      builder: (_, _) => ListView(padding: const EdgeInsets.all(20), children: [
        Text('Thiết bị đăng nhập', style: t(18, w: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final s in store.security.sessions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(s.platform == 'ios' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded),
            title: Text(s.current ? '${s.name} (máy này)' : s.name, style: t(14.5, w: FontWeight.w600)),
            subtitle: Text(s.lastUsed == null ? '' : 'Hoạt động ${ago(s.lastUsed!)}', style: t(12.5, color: C.sub)),
            trailing: s.current
                ? null
                : IconButton(
                    icon: const Icon(Icons.logout_rounded, color: C.red),
                    onPressed: () async {
                      try {
                        await store.revokeSession(s);
                        toast('Đã đăng xuất thiết bị.');
                      } on ApiException catch (e) {
                        toast(e.message);
                      }
                    }),
          ),
      ]),
    ),
  );
}
