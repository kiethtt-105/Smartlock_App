import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth_state.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'form_pages.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Widget _row(IconData icon, String title, {Widget? right, VoidCallback? onTap}) => Tap(
        onTap: onTap,
        scale: .985,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: C.violet.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: C.violet, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: t(15, w: FontWeight.w600))),
            right ?? const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: C.sub),
          ]),
        ),
      );

  Widget _group(List<Widget> rows) => Glass(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: C.stroke, indent: 68),
            rows[i],
          ],
        ]),
      );

  Widget _on(bool v) => Pill(v ? 'Đã bật' : 'Chưa bật', v ? C.green : C.sub);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (ctx, _) => _body(ctx),
      );

  Widget _body(BuildContext context) => SafeArea(
        bottom: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 130), children: [
          Reveal(index: 0, child: Text('Tôi', style: t(32, w: FontWeight.w800, ls: -1))),
          const SizedBox(height: 20),
          Reveal(
            index: 1,
            child: Glass(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                  width: 68, height: 68,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: C.grad),
                  child: Text(store.userName.isEmpty ? '?' : store.userName[0].toUpperCase(), style: t(28, w: FontWeight.w800)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(store.userName, style: t(19, w: FontWeight.w800, ls: -.4)),
                    const SizedBox(height: 2),
                    Text(store.userEmail, style: t(13, color: C.sub)),
                    const SizedBox(height: 10),
                    store.security.enabled
                        ? const Pill('2FA đang bật', C.green, icon: Icons.verified_user_rounded)
                        : const Pill('2FA chưa bật', C.sub, icon: Icons.shield_outlined),
                  ]),
                ),
              ]),
            ),
          ),
          const Section('Xác thực 2 bước'),
          Reveal(
            index: 2,
            child: _group([
              _row(Icons.phonelink_lock_rounded, 'Google Authenticator', right: _on(store.security.totp),
                  onTap: () => showTwoFa(context, 'totp', store.security.totp)),
              _row(Icons.mail_outline_rounded, 'Mã qua email', right: _on(store.security.emailOtp),
                  onTap: () => showTwoFa(context, 'email', store.security.emailOtp)),
              _row(Icons.fingerprint_rounded, 'Passkey',
                  right: Pill(store.security.passkeys > 0 ? '${store.security.passkeys} · chỉ web' : 'Chỉ web', C.sub)),
            ]),
          ),
          const Section('Tài khoản'),
          Reveal(
            index: 3,
            child: _group([
              _row(Icons.notifications_none_rounded, 'Thông báo', onTap: () => context.push('/notifications')),
              _row(Icons.person_outline_rounded, 'Thông tin cá nhân', onTap: () => showEditProfile(context)),
              _row(Icons.devices_rounded, 'Thiết bị đăng nhập', onTap: () => showSessions(context)),
              _row(Icons.password_rounded, 'Đổi mật khẩu', onTap: () => showChangePassword(context)),
              _row(Icons.history_rounded, 'Nhật ký hệ thống', onTap: () => showAuditLog(context)),
            ]),
          ),
          const SizedBox(height: 26),
          Reveal(
            index: 4,
            child: Tap(
              onTap: auth.logout,
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.red.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: C.red.withValues(alpha: .35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.logout_rounded, color: C.red, size: 20),
                  const SizedBox(width: 8),
                  Text('Đăng xuất', style: t(15.5, w: FontWeight.w700, color: C.red)),
                ]),
              ),
            ),
          ),
        ]),
      );
}
