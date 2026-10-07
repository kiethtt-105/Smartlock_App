import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';
import 'form_pages.dart';

/// Các trang mở từ link trong email. Đường dẫn trùng với web (Django) để App Links / deep link map thẳng vào:
///   /verify-email/<token>/          -> VerifyEmailScreen
///   /reset-password/<uid>/<token>/  -> ResetPasswordScreen

String _msgOf(Object e) => e is ApiException ? e.message : 'Đã có lỗi xảy ra, vui lòng thử lại.';

class _Result extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, text;
  const _Result(this.icon, this.color, this.title, this.text);

  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 24),
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .15)),
          child: Icon(icon, color: color, size: 40),
        ),
        const SizedBox(height: 18),
        Text(title, style: t(20, w: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(text, style: t(14.5, color: C.sub, h: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        GradBtn('Về trang đăng nhập', onTap: () => context.go('/login')),
      ]);
}

// ============================================================ Xác thực email
class VerifyEmailScreen extends StatefulWidget {
  final String token;
  const VerifyEmailScreen({super.key, required this.token});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmailScreen> {
  bool _loading = true;
  String? _err, _ok;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await api.request('POST', Endpoints.verifyEmail, body: {'token': widget.token}, auth: false);
      _ok = '${r['message'] ?? 'Tài khoản đã được kích hoạt thành công!'}';
    } catch (e) {
      _err = _msgOf(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => PageShell(
        title: 'Xác thực email',
        onBack: () => context.go('/login'),
        children: [
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
          else if (_ok != null)
            _Result(Icons.check_circle_rounded, C.green, 'Đã kích hoạt', _ok!)
          else
            Column(children: [
              _Result(Icons.error_outline_rounded, C.red, 'Không xác thực được', _err ?? ''),
              const SizedBox(height: 12),
              GradBtn('Thử lại', filled: false, onTap: _verify),
            ]),
        ],
      );
}

// ============================================================ Đặt lại mật khẩu bằng link
class ResetPasswordScreen extends StatefulWidget {
  final String uid, token;
  const ResetPasswordScreen({super.key, required this.uid, required this.token});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordState();
}

enum _Step { checking, invalid, form, done }

class _ResetPasswordState extends State<ResetPasswordScreen> {
  final _pw = TextEditingController(), _pw2 = TextEditingController();
  _Step _step = _Step.checking;
  bool _busy = false, _hide = true;
  String? _err, _doneMsg;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _link => {'uid': widget.uid, 'token': widget.token};

  Future<void> _check() async {
    try {
      await api.request('POST', Endpoints.passwordResetCheck, body: _link, auth: false);
      _step = _Step.form;
    } catch (e) {
      _err = _msgOf(e);
      _step = _Step.invalid;
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_pw.text.isEmpty) return setState(() => _err = 'Nhập mật khẩu mới.');
    if (_pw.text != _pw2.text) return setState(() => _err = 'Hai mật khẩu không khớp.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final r = await api.request('POST', Endpoints.passwordResetConfirm,
          body: {..._link, 'new_password': _pw.text}, auth: false);
      _doneMsg = '${r['message'] ?? 'Mật khẩu đã được thay đổi thành công!'}';
      _step = _Step.done;
    } catch (e) {
      _err = _msgOf(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => PageShell(
        title: 'Đặt lại mật khẩu',
        onBack: () => context.go('/login'),
        children: switch (_step) {
          _Step.checking => [
              const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()))
            ],
          _Step.invalid => [_Result(Icons.link_off_rounded, C.red, 'Link không dùng được', _err ?? '')],
          _Step.done => [
              _Result(Icons.check_circle_rounded, C.green, 'Đã đổi mật khẩu',
                  '${_doneMsg ?? ''}\nCác thiết bị khác sẽ bị đăng xuất.')
            ],
          _Step.form => [
              Text('Nhập mật khẩu mới cho tài khoản của bạn.', style: t(14.5, color: C.sub)),
              const SizedBox(height: 16),
              TextField(
                controller: _pw,
                obscureText: _hide,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hide = !_hide)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pw2,
                obscureText: _hide,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu mới'),
              ),
              const SizedBox(height: 22),
              if (_err != null) ErrorBox(_err!),
              GradBtn('Đổi mật khẩu', loading: _busy, onTap: _submit),
            ],
        },
      );
}
