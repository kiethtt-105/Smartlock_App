import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/smartlock_api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/helpers.dart';
import 'main_screen.dart';

enum _Mode { login, twoFactor, register }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.login;
  bool _busy = false;
  bool _showPw = false;

  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _code = TextEditingController();

  String? _challenge;
  List<String> _methods = [];
  String _method = 'totp';

  @override
  void dispose() {
    for (final c in [_id, _pw, _email, _username, _fullName, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        await _offerResend();
      } else {
        showMsg(context, e.message, error: true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offerResend() async {
    final ok = await confirmDialog(context,
        title: 'Chưa xác thực email',
        text: 'Tài khoản chưa được kích hoạt. Gửi lại email xác thực?',
        okText: 'Gửi lại');
    if (!ok) return;
    final email = _id.text.contains('@') ? _id.text.trim() : (await promptDialog(context, title: 'Nhập email đã đăng ký', keyboard: TextInputType.emailAddress, okText: 'Gửi') ?? '');
    if (email.isEmpty) return;
    try {
      await SmartlockApi.resendVerification(email);
      if (mounted) showMsg(context, 'Nếu tài khoản cần xác thực, email đã được gửi lại.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _login() => _run(() async {
        final id = _id.text.trim();
        if (id.isEmpty || _pw.text.isEmpty) {
          showMsg(context, 'Vui lòng nhập email/username và mật khẩu.', error: true);
          return;
        }
        final j = await SmartlockApi.login(id, _pw.text);
        if (j['two_factor_required'] == true) {
          _challenge = j['challenge_token'] as String;
          _methods = ((j['methods'] as List?) ?? []).map((e) => e.toString()).toList();
          final pref = (j['preferred_method'] ?? '').toString();
          _method = _methods.contains(pref) ? pref : _methods.first;
          _code.clear();
          setState(() => _mode = _Mode.twoFactor);
          if (_method == 'email') await _sendEmailCode();
        } else {
          await _finish(j);
        }
      });

  Future<void> _sendEmailCode() async {
    await SmartlockApi.twoFactorEmailSend(_challenge!);
    if (mounted) showMsg(context, 'Đã gửi mã xác thực qua email.');
  }

  Future<void> _verify() => _run(() async {
        if (_code.text.trim().isEmpty) {
          showMsg(context, 'Hãy nhập mã xác thực.', error: true);
          return;
        }
        final j = await SmartlockApi.twoFactorVerify(_challenge!, _method, _code.text.trim());
        await _finish(j);
      });

  Future<void> _finish(Map<String, dynamic> j) async {
    await AppState.instance.onLogin(j);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  Future<void> _register() => _run(() async {
        final msg = await SmartlockApi.register(
          email: _email.text.trim(),
          username: _username.text.trim(),
          fullName: _fullName.text.trim(),
          password: _pw.text,
        );
        if (!mounted) return;
        _id.text = _email.text.trim();
        setState(() => _mode = _Mode.login);
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Đăng ký thành công'),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      });

  Future<void> _forgot() async {
    final email = await promptDialog(context,
        title: 'Quên mật khẩu',
        hint: 'Email đã đăng ký',
        keyboard: TextInputType.emailAddress,
        okText: 'Gửi');
    if (email == null || email.isEmpty) return;
    try {
      final msg = await SmartlockApi.passwordReset(email);
      if (mounted) showMsg(context, msg);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smartlock',
                    style: TextStyle(color: AppColors.blue, fontSize: 40, fontWeight: FontWeight.w800)),
                Text(_subtitle,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 32),
                ..._fields(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _primaryAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Text(_primaryLabel, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 8),
                ..._links(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _subtitle => switch (_mode) {
        _Mode.login => 'Đăng nhập để quản lý khóa của bạn',
        _Mode.twoFactor => 'Xác thực 2 lớp',
        _Mode.register => 'Tạo tài khoản mới',
      };

  String get _primaryLabel => switch (_mode) {
        _Mode.login => 'Đăng nhập',
        _Mode.twoFactor => 'Xác nhận',
        _Mode.register => 'Đăng ký',
      };

  VoidCallback get _primaryAction => switch (_mode) {
        _Mode.login => _login,
        _Mode.twoFactor => _verify,
        _Mode.register => _register,
      };

  InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _gap() => const SizedBox(height: 14);

  List<Widget> _fields() {
    switch (_mode) {
      case _Mode.login:
        return [
          TextField(
            controller: _id,
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('Email hoặc tên đăng nhập'),
          ),
          _gap(),
          _pwField('Mật khẩu'),
        ];
      case _Mode.twoFactor:
        return [
          if (_methods.length > 1)
            Wrap(
              spacing: 8,
              children: [
                for (final m in _methods)
                  ChoiceChip(
                    label: Text(m == 'totp' ? 'Ứng dụng xác thực' : 'Email'),
                    selected: _method == m,
                    onSelected: (_) async {
                      setState(() => _method = m);
                      if (m == 'email') await _run(_sendEmailCode);
                    },
                  ),
              ],
            ),
          if (_methods.length > 1) _gap(),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: _dec(_method == 'totp' ? 'Mã từ ứng dụng xác thực' : 'Mã gửi qua email'),
          ),
        ];
      case _Mode.register:
        return [
          TextField(controller: _fullName, decoration: _dec('Họ và tên')),
          _gap(),
          TextField(
            controller: _username,
            decoration: _dec('Tên đăng nhập (không chứa @)'),
          ),
          _gap(),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: _dec('Email'),
          ),
          _gap(),
          _pwField('Mật khẩu'),
        ];
    }
  }

  Widget _pwField(String label) => TextField(
        controller: _pw,
        obscureText: !_showPw,
        decoration: _dec(
          label,
          suffix: IconButton(
            icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPw = !_showPw),
          ),
        ),
      );

  List<Widget> _links() {
    switch (_mode) {
      case _Mode.login:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _forgot,
                child: const Text('Quên mật khẩu?',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.register),
                child: const Text('Đăng ký', style: TextStyle(color: AppColors.blue)),
              ),
            ],
          ),
          Center(
            child: Text('Máy chủ: ${_host(ApiClient.instance.activeBase)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ),
        ];
      case _Mode.twoFactor:
        return [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _mode = _Mode.login),
                child: const Text('Quay lại', style: TextStyle(color: AppColors.textSecondary)),
              ),
              if (_method == 'email')
                TextButton(
                  onPressed: _busy ? null : () => _run(_sendEmailCode),
                  child: const Text('Gửi lại mã', style: TextStyle(color: AppColors.blue)),
                ),
            ],
          ),
        ];
      case _Mode.register:
        return [
          Center(
            child: TextButton(
              onPressed: () => setState(() => _mode = _Mode.login),
              child: const Text('Đã có tài khoản? Đăng nhập',
                  style: TextStyle(color: AppColors.blue)),
            ),
          ),
        ];
    }
  }

  String _host(String base) => Uri.parse(base).host;
}
