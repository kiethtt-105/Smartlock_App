import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/auth_state.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutBack,
              builder: (ctx, v, child) => Opacity(
                  opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: .7 + .3 * v, child: child)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const LogoMark(size: 92),
                const SizedBox(height: 26),
                Text('Smartlock', style: t(32, w: FontWeight.w800, ls: -1)),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 110,
                  child: LinearProgressIndicator(
                      minHeight: 3, color: C.violet, backgroundColor: C.card2,
                      borderRadius: BorderRadius.all(Radius.circular(9))),
                ),
              ]),
            ),
          ),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false, _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 900)); // giả lập gọi API
    auth.login(_email.text, _pass.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Reveal(index: 0, child: LogoMark(size: 60)),
                    const SizedBox(height: 30),
                    Reveal(
                        index: 1,
                        child: Text('Mở cửa\nbằng một chạm.', style: t(38, w: FontWeight.w800, ls: -1.4, h: 1.05))),
                    const SizedBox(height: 10),
                    Reveal(index: 2, child: Text('Đăng nhập để điều khiển khóa của bạn.', style: t(15, color: C.sub))),
                    const SizedBox(height: 34),
                    Reveal(
                      index: 3,
                      child: TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Reveal(
                      index: 4,
                      child: TextField(
                        controller: _pass,
                        obscureText: _hide,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _hide = !_hide)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () {}, child: const Text('Quên mật khẩu?'))),
                    const SizedBox(height: 10),
                    Reveal(index: 5, child: GradBtn('Đăng nhập', loading: _busy, onTap: _submit)),
                    const SizedBox(height: 14),
                    Reveal(
                        index: 6,
                        child: Center(
                            child: TextButton(onPressed: () {}, child: const Text('Chưa có tài khoản? Đăng ký')))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class TwoFaScreen extends StatefulWidget {
  const TwoFaScreen({super.key});
  @override
  State<TwoFaScreen> createState() => _TwoFaScreenState();
}

class _TwoFaScreenState extends State<TwoFaScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 800));
    auth.verifyTwoFa(_code.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: GlowBg(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RoundBtn(Icons.arrow_back_rounded, onTap: auth.backToLogin),
                const SizedBox(height: 34),
                Reveal(
                    index: 0,
                    child: Text('Nhập mã\nxác thực.', style: t(38, w: FontWeight.w800, ls: -1.4, h: 1.05))),
                const SizedBox(height: 10),
                Reveal(
                    index: 1,
                    child: Text('Mã 6 số từ ứng dụng xác thực của bạn.\n(Giả lập: nhập gì cũng được)',
                        style: t(15, color: C.sub, h: 1.4))),
                const SizedBox(height: 36),
                Reveal(
                  index: 2,
                  child: GestureDetector(
                    onTap: () => _focus.requestFocus(),
                    child: Stack(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        for (int i = 0; i < 6; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 48, height: 62,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: C.card2,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: i == _code.text.length ? C.violet : Colors.transparent, width: 1.6),
                            ),
                            child: Text(i < _code.text.length ? _code.text[i] : '',
                                style: t(26, w: FontWeight.w800)),
                          ),
                      ]),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0,
                          child: TextField(
                            controller: _code,
                            focusNode: _focus,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                            decoration: const InputDecoration(filled: false, border: InputBorder.none),
                            onChanged: (v) {
                              setState(() {});
                              if (v.length == 6) _submit();
                            },
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 30),
                Reveal(index: 3, child: GradBtn('Xác nhận', loading: _busy, onTap: _code.text.length == 6 ? _submit : null)),
              ]),
            ),
          ),
        ),
      );
}
