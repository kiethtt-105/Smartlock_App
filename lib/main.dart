import 'dart:async';
import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/store.dart';

final store = Store();
const kA = Color(0xFF0A84FF), kA2 = Color(0xFF5E5CE6);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.i.init();
  await store.init();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _in = Api.i.hasSession;
  @override
  void initState() {
    super.initState();
    Api.i.onLoggedOut = () async {
      await store.reset();
      if (mounted) setState(() => _in = false);
    };
    if (_in) store.start();
  }

  ThemeData _th(Brightness b) => ThemeData(
      useMaterial3: true,
      colorSchemeSeed: kA,
      brightness: b,
      scaffoldBackgroundColor: b == Brightness.dark ? Colors.black : const Color(0xFFF2F2F7),
      cardTheme: CardThemeData(
          elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))));

  @override
  Widget build(BuildContext c) => MaterialApp(
      title: 'Smart Lock',
      debugShowCheckedModeBanner: false,
      theme: _th(Brightness.light),
      darkTheme: _th(Brightness.dark),
      home: _in
          ? Shell(onOut: () async {
              await Api.i.logout();
              await store.reset();
              setState(() => _in = false);
            })
          : Login(onDone: () {
              store.start();
              setState(() => _in = true);
            }));
}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

// ---------------- ĐĂNG NHẬP + 2FA ----------------
class Login extends StatefulWidget {
  final VoidCallback onDone;
  const Login({super.key, required this.onDone});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final id = TextEditingController(), pw = TextEditingController(), code = TextEditingController();
  String? ch, method, err;
  List methods = [];
  bool loading = false;

  Future<void> go() async {
    setState(() {
      loading = true;
      err = null;
    });
    final r = ch == null ? await Api.i.login(id.text.trim(), pw.text) : await Api.i.verify2fa(ch!, method!, code.text.trim());
    if (!mounted) return;
    setState(() => loading = false);
    if (!r.ok) return setState(() => err = r.msg);
    if (r.d['two_factor_required'] == true) {
      return setState(() {
        ch = r.d['challenge_token'];
        methods = (r.d['methods'] as List).where((m) => m != 'fido2').toList(); // passkey chỉ có trên web
        method = r.d['preferred_method'] ?? (methods.isNotEmpty ? methods.first : null);
      });
    }
    widget.onDone();
  }

  Future<void> sendMail() async {
    final r = await Api.i.call('POST', 'auth/2fa/email/send/', body: {'challenge_token': ch}, auth: false);
    if (mounted) snack(context, r.ok ? 'Đã gửi mã tới ${r.d['masked_email']}' : r.msg);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 50),
        Center(
            child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [kA, kA2]), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.lock, color: Colors.white, size: 30))),
        const SizedBox(height: 16),
        Text(ch == null ? 'Chào mừng trở lại' : 'Xác thực 2 lớp',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        if (err != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(err!, style: const TextStyle(color: Colors.red))),
        if (ch == null) ...[
          TextField(controller: id, decoration: const InputDecoration(labelText: 'Email hoặc username', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu', border: OutlineInputBorder())),
        ] else ...[
          if (methods.length > 1)
            DropdownButtonFormField(
                value: method,
                items: [for (final m in methods) DropdownMenuItem(value: m, child: Text(m == 'totp' ? 'Google Authenticator' : 'Email OTP'))],
                onChanged: (v) => setState(() => method = v as String?)),
          const SizedBox(height: 12),
          TextField(
              controller: code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 6),
              decoration: const InputDecoration(hintText: 'Mã 6 số', border: OutlineInputBorder())),
          if (methods.contains('email')) TextButton(onPressed: sendMail, child: const Text('Gửi mã qua email')),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : go, child: Text(loading ? 'Đang xử lý…' : ch == null ? 'Đăng nhập' : 'Xác nhận')),
      ])));
}

// ---------------- KHUNG CHÍNH ----------------
class Shell extends StatefulWidget {
  final VoidCallback onOut;
  const Shell({super.key, required this.onOut});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final pages = [_home(), _events(), _cards(), _notes(), _profile()];
        return Scaffold(
            body: SafeArea(
                child: Column(children: [
              if (!store.online)
                Container(
                    width: double.infinity,
                    color: Colors.orange,
                    padding: const EdgeInsets.all(6),
                    child: const Text('Đang offline · dữ liệu lưu trên máy · mở khóa bằng Bluetooth', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12))),
              Expanded(child: RefreshIndicator(onRefresh: store.sync, child: pages[tab])),
            ])),
            bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: [
              const NavigationDestination(icon: Icon(Icons.lock_outline), label: 'Khóa'),
              const NavigationDestination(icon: Icon(Icons.history), label: 'Lịch sử'),
              const NavigationDestination(icon: Icon(Icons.credit_card), label: 'Thẻ'),
              NavigationDestination(icon: Badge(isLabelVisible: (store.S['unread_count'] ?? 0) > 0, label: Text('${store.S['unread_count']}'), child: const Icon(Icons.notifications_none)), label: 'Thông báo'),
              const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Tôi'),
            ]));
      });

  Widget _wrap(String t, List<Widget> ch) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(t, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...ch,
        if (ch.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Chưa có dữ liệu'))),
      ]);

  Widget _home() => _wrap('Khóa của tôi', [
        for (final d in store.devices)
          Card(
              child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Icon(d['lock_state'] == 'unlocked' ? Icons.lock_open : Icons.lock, color: d['lock_state'] == 'unlocked' ? Colors.orange : Colors.green, size: 32),
                  title: Text(d['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${d['lock_state'] == 'unlocked' ? 'Đang mở' : 'Đã khóa'} · Pin ${d['battery_level'] ?? '—'}%'),
                  trailing: Chip(label: Text(d['status'] == 'online' ? 'Online' : 'Offline')),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DevicePage(id: d['id']))))),
      ]);

  Widget _events() => _wrap('Lịch sử ra vào', [
        for (final e in store.list('history')) ListTile(leading: Icon(e['success'] == false ? Icons.error_outline : Icons.check_circle_outline), title: Text('${e['user_name'] ?? e['user'] ?? ''} ${e['method'] ?? e['event_type'] ?? ''}'), subtitle: Text('${e['device_name'] ?? e['device'] ?? ''}'), trailing: Text('${(e['created_at'] ?? '').toString().split('T').first}'))
      ]);

  Widget _cards() => _wrap('Thẻ NFC', [
        for (final k in store.list('cards'))
          Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              height: 120,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [kA, kA2]), borderRadius: BorderRadius.circular(22)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(k['is_active'] == true ? 'Đang bật' : 'Đã tắt', style: const TextStyle(color: Colors.white70)),
                Text(k['name'] ?? 'Thẻ NFC', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              ]))
      ]);

  Widget _notes() => _wrap('Thông báo', [
        for (final n in store.list('notifications')) ListTile(leading: Icon(n['severity'] == 'critical' ? Icons.warning_amber : Icons.notifications_none), title: Text(n['title'] ?? ''), subtitle: Text(n['message'] ?? ''))
      ]);

  Widget _profile() {
    final u = store.S['user'] ?? {};
    return _wrap('Tài khoản', [
      Card(child: ListTile(leading: CircleAvatar(child: Text('${u['initials'] ?? '?'}')), title: Text('${u['full_name'] ?? u['username'] ?? ''}'), subtitle: Text('${u['email'] ?? ''}'))),
      FilledButton.tonal(onPressed: widget.onOut, child: const Text('Đăng xuất')),
    ]);
  }
}

// ---------------- CHI TIẾT KHÓA (giữ 0,7s để mở) ----------------
class DevicePage extends StatefulWidget {
  final String id;
  const DevicePage({super.key, required this.id});
  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> with SingleTickerProviderStateMixin {
  late final AnimationController hold = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  Future<void> fire(Map d) async {
    final cmd = d['lock_state'] == 'unlocked' ? 'LOCK' : 'UNLOCK';
    final err = await store.act(d, cmd);
    if (mounted) snack(context, err ?? (cmd == 'UNLOCK' ? 'Đã mở khóa' : 'Đã khóa'));
  }

  @override
  Widget build(BuildContext c) => ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final d = store.devices.firstWhere((x) => x['id'] == widget.id, orElse: () => null) as Map?;
        if (d == null) return const Scaffold(body: Center(child: Text('Không tìm thấy khóa')));
        final open = d['lock_state'] == 'unlocked', busy = store.busy.contains(widget.id);
        final perms = (d['permissions'] as List?) ?? [];
        final can = d['is_owner'] == true || perms.contains('UNLOCK') || perms.contains('LOCK');
        final hasTicket = store.tickets.containsKey(widget.id);
        return Scaffold(
            appBar: AppBar(title: Text(d['name'])),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              Center(
                  child: GestureDetector(
                      onTapDown: (_) {
                        if (!can || busy) return;
                        open ? fire(d) : hold.forward(from: 0).then((_) => fire(d));
                      },
                      onTapUp: (_) => hold.status != AnimationStatus.completed ? hold.reset() : null,
                      onTapCancel: () => hold.reset(),
                      child: AnimatedBuilder(
                          animation: hold,
                          builder: (_, __) => Stack(alignment: Alignment.center, children: [
                                SizedBox(width: 190, height: 190, child: CircularProgressIndicator(value: busy ? null : (open ? 1 : hold.value), strokeWidth: 8, color: open ? Colors.orange : Colors.green)),
                                Icon(open ? Icons.lock_open : Icons.lock, size: 80, color: open ? Colors.orange : Colors.green),
                              ])))),
              const SizedBox(height: 12),
              Center(child: Text(open ? 'Chạm để khóa' : 'Giữ để mở khóa', style: const TextStyle(color: Colors.grey))),
              const SizedBox(height: 8),
              Center(child: Text(open ? 'Đang mở' : 'Đã khóa', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
              Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                Chip(label: Text(d['status'] == 'online' ? 'Đang kết nối' : 'Mất kết nối')),
                Chip(label: Text('Pin ${d['battery_level'] ?? '—'}%')),
                if (d['bluetooth_enabled'] == true) Chip(avatar: Icon(hasTicket ? Icons.bluetooth_connected : Icons.bluetooth_disabled, size: 16), label: Text(hasTicket ? 'Sẵn sàng mở offline' : 'Chưa có vé offline')),
              ]),
              const SizedBox(height: 16),
              if (d['bluetooth_enabled'] == true && can)
                OutlinedButton.icon(
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('Mở bằng Bluetooth'),
                    onPressed: busy ? null : () async {
                      final e = await store.unlockBle(d);
                      if (mounted) snack(context, e ?? 'Đã gửi vé tới khóa ✓');
                    }),
            ]));
      });
}
