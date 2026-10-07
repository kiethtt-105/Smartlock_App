import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/auth_state.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../widgets/ui.dart';

/// Chuyển trang kiểu fade + trượt nhẹ (cùng phong cách router.dart) cho các trang mở bằng Navigator.
PageRoute<T> slideRoute<T>(Widget child) => PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (_, anim, _, c) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, .05), end: Offset.zero).animate(curved), child: c),
        );
      },
    );

/// Khung một trang riêng: nút quay lại + tiêu đề + nội dung cuộn.
class PageShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;
  const PageShell({super.key, required this.title, this.subtitle, required this.children, this.onBack});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 40), children: [
                  Row(children: [
                    RoundBtn(Icons.arrow_back_rounded, onTap: onBack ?? () => Navigator.of(context).maybePop()),
                    const SizedBox(width: 16),
                    Expanded(child: Text(title, style: t(24, w: FontWeight.w800, ls: -.6))),
                  ]),
                  if (subtitle != null)
                    Padding(padding: const EdgeInsets.only(top: 16), child: Text(subtitle!, style: t(14.5, color: C.sub, h: 1.4))),
                  const SizedBox(height: 22),
                  ...children,
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Lỗi hiện ngay trên trang (thay cho popup/toast).
class ErrorBox extends StatelessWidget {
  final String text;
  const ErrorBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.red.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.red.withValues(alpha: .35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, color: C.red, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: t(13.5, color: C.red))),
        ]),
      );
}

/// Màn thông báo thành công (dùng sau khi đăng ký / gửi email đặt lại mật khẩu).
class _DoneView extends StatelessWidget {
  final String message, button;
  final VoidCallback onTap;
  const _DoneView({required this.message, required this.button, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        const Center(child: Icon(Icons.mark_email_read_rounded, color: C.green, size: 64)),
        const SizedBox(height: 18),
        Text(message, textAlign: TextAlign.center, style: t(15, h: 1.45)),
        const SizedBox(height: 28),
        GradBtn(button, onTap: onTap),
      ]);
}

void _backToLogin(BuildContext context) => context.canPop() ? context.pop() : context.go('/login');

// ============================================================ Trang nhập liệu dùng chung (thay showDialog)
/// Mở trang nhập liệu toàn màn hình. Chạy [submit], lỗi từ server hiện ngay trên trang, thành công thì quay lại.
Future<void> showForm(
  BuildContext context, {
  required String title,
  required String action,
  required List<(String label, bool secret, TextInputType? type)> fields,
  required Future<String?> Function(List<String> v) submit,
  String? info,
  List<String>? initial,
}) =>
    Navigator.of(context).push<void>(slideRoute(
        FormPage(title: title, action: action, fields: fields, submit: submit, info: info, initial: initial)));

class FormPage extends StatefulWidget {
  final String title, action;
  final String? info;
  final List<(String label, bool secret, TextInputType? type)> fields;
  final List<String>? initial;
  final Future<String?> Function(List<String> v) submit;
  const FormPage({
    super.key,
    required this.title,
    required this.action,
    required this.fields,
    required this.submit,
    this.info,
    this.initial,
  });

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  late final List<TextEditingController> _c;
  late final List<bool> _hide;
  bool _busy = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _c = [
      for (int i = 0; i < widget.fields.length; i++)
        TextEditingController(text: init != null && i < init.length ? init[i] : '')
    ];
    _hide = [for (final f in widget.fields) f.$2];
  }

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    String? err;
    try {
      final msg = await widget.submit([
        for (int i = 0; i < _c.length; i++) widget.fields[i].$2 ? _c[i].text : _c[i].text.trim()
      ]);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (msg != null) toast(msg);
      return;
    } on ApiException catch (e) {
      err = e.message;
    } catch (e, st) {
      debugPrint('${widget.title}: $e\n$st');
      err = 'Đã có lỗi xảy ra, vui lòng thử lại.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _err = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
        title: widget.title,
        children: [
          if (widget.info != null) ...[
            SelectableText(widget.info!, style: t(14, color: C.sub, h: 1.45)),
            const SizedBox(height: 8),
          ],
          for (int i = 0; i < widget.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: _c[i],
                obscureText: _hide[i],
                keyboardType: widget.fields[i].$3,
                textInputAction: i == widget.fields.length - 1 ? TextInputAction.done : TextInputAction.next,
                onSubmitted: i == widget.fields.length - 1 ? (_) => _go() : null,
                decoration: InputDecoration(
                  labelText: widget.fields[i].$1,
                  suffixIcon: widget.fields[i].$2
                      ? IconButton(
                          icon: Icon(_hide[i] ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _hide[i] = !_hide[i]))
                      : null,
                ),
              ),
            ),
          const SizedBox(height: 22),
          if (_err != null) ErrorBox(_err!),
          GradBtn(widget.action, loading: _busy, onTap: _go),
        ],
      );
}

// ============================================================ Đăng ký
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController(), _user = TextEditingController();
  final _email = TextEditingController(), _pass = TextEditingController();
  bool _busy = false, _hide = true;
  String? _err, _done;

  @override
  void dispose() {
    for (final c in [_name, _user, _email, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    final user = _user.text.trim(), email = _email.text.trim();
    if (user.isEmpty || email.isEmpty || _pass.text.isEmpty) {
      setState(() => _err = 'Nhập đủ tên đăng nhập, email và mật khẩu.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    String? err, done;
    try {
      done = await auth.register(fullName: _name.text.trim(), username: user, email: email, password: _pass.text);
    } on ApiException catch (e) {
      err = e.message;
    } catch (e, st) {
      debugPrint('register: $e\n$st');
      err = 'Đã có lỗi xảy ra, vui lòng thử lại.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _err = err;
        _done = done;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
        title: 'Đăng ký',
        subtitle: _done == null ? 'Tạo tài khoản để quản lý khóa thông minh của bạn.' : null,
        onBack: () => _backToLogin(context),
        children: _done != null
            ? [_DoneView(message: _done!, button: 'Về đăng nhập', onTap: () => _backToLogin(context))]
            : [
                TextField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Họ tên', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _user,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _go(),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hide = !_hide)),
                  ),
                ),
                const SizedBox(height: 22),
                if (_err != null) ErrorBox(_err!),
                GradBtn('Đăng ký', loading: _busy, onTap: _go),
                const SizedBox(height: 10),
                Center(child: TextButton(onPressed: () => _backToLogin(context), child: const Text('Đã có tài khoản? Đăng nhập'))),
              ],
      );
}

// ============================================================ Quên mật khẩu
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _err, _done;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _err = 'Nhập email.');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    String? err, done;
    try {
      done = await auth.forgotPassword(email);
    } on ApiException catch (e) {
      err = e.message;
    } catch (e, st) {
      debugPrint('forgot: $e\n$st');
      err = 'Đã có lỗi xảy ra, vui lòng thử lại.';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _err = err;
        _done = done;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
        title: 'Quên mật khẩu',
        subtitle: _done == null ? 'Nhập email đã đăng ký, chúng tôi sẽ gửi link đặt lại mật khẩu.' : null,
        onBack: () => _backToLogin(context),
        children: _done != null
            ? [_DoneView(message: _done!, button: 'Về đăng nhập', onTap: () => _backToLogin(context))]
            : [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _go(),
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                ),
                const SizedBox(height: 22),
                if (_err != null) ErrorBox(_err!),
                GradBtn('Gửi link đặt lại', loading: _busy, onTap: _go),
              ],
      );
}

// ============================================================ Nhật ký hệ thống
void showAuditLog(BuildContext context) {
  Navigator.of(context).push<void>(slideRoute(const AuditScreen()));
}

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) => PageShell(
        title: 'Nhật ký hệ thống',
        children: [
          ListenableBuilder(
            listenable: store,
            builder: (_, _) => store.audit.isEmpty
                ? const EmptyBox(Icons.history_rounded, 'Chưa có nhật ký.')
                : Column(children: [
                    for (final a in store.audit)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(a.success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                            color: a.success ? C.green : C.red),
                        title: Text(a.action, style: t(14, w: FontWeight.w600)),
                        subtitle: Text('${a.device.isEmpty ? '—' : a.device} · ${ago(a.at)}', style: t(12.5, color: C.sub)),
                      ),
                  ]),
          ),
        ],
      );
}

// ============================================================ Thiết bị đang đăng nhập
void showSessions(BuildContext context) {
  Navigator.of(context).push<void>(slideRoute(const SessionsScreen()));
}

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) => PageShell(
        title: 'Thiết bị đăng nhập',
        children: [
          ListenableBuilder(
            listenable: store,
            builder: (_, _) => Column(children: [
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
        ],
      );
}

// ============================================================ Mã PIN của khách (hiện một lần)
class PinResultPage extends StatelessWidget {
  final String pin;
  const PinResultPage(this.pin, {super.key});

  @override
  Widget build(BuildContext context) => PageShell(
        title: 'Mã PIN của khách',
        children: [
          const SizedBox(height: 10),
          Center(child: SelectableText(pin, style: t(44, w: FontWeight.w800, ls: 6))),
          const SizedBox(height: 14),
          Text('Mã chỉ hiện một lần. Hãy gửi cho khách ngay.', textAlign: TextAlign.center, style: t(13.5, color: C.sub)),
          const SizedBox(height: 28),
          GradBtn('Sao chép mã', icon: Icons.copy_rounded, filled: false, onTap: () async {
            await Clipboard.setData(ClipboardData(text: pin));
            toast('Đã sao chép.');
          }),
          const SizedBox(height: 12),
          GradBtn('Xong', onTap: () => Navigator.of(context).pop()),
        ],
      );
}

// ============================================================ Trang chọn một mục (thay SimpleDialog)
class OptionPage extends StatelessWidget {
  final String title;
  final Map<String, String> options;
  const OptionPage({super.key, required this.title, required this.options});

  @override
  Widget build(BuildContext context) => PageShell(
        title: title,
        children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Tap(
                onTap: () => Navigator.of(context).pop(e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    color: C.card2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: C.stroke),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(e.value, style: t(15, w: FontWeight.w600))),
                    const Icon(Icons.chevron_right_rounded, color: C.sub),
                  ]),
                ),
              ),
            ),
        ],
      );
}
