import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/permission_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../nav.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  List<bool> _granted = List.filled(PermissionService.items.length, false);
  bool _needSettings = false;
  bool _busy = false;

  bool get _all => _granted.every((g) => g);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  // Vào màn hình là xin quyền luôn (chưa cấp thì hiện hộp thoại lần lượt).
  Future<void> _init() async {
    await _refresh();
    if (!mounted || _all || _needSettings) return;
    await _grantAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Quay lại từ Cài đặt hệ thống thì kiểm tra lại.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = <bool>[];
    var needSettings = false;
    for (final p in PermissionService.items) {
      final ok = await PermissionService.isGranted(p);
      granted.add(ok);
      if (!ok && await PermissionService.isPermanentlyDenied(p)) {
        needSettings = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _needSettings = needSettings;
    });
  }

  Future<void> _grantAll() async {
    setState(() => _busy = true);
    for (final p in PermissionService.items) {
      if (!await PermissionService.isGranted(p)) {
        await PermissionService.request(p);
      }
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _next() async {
    final next = await resolveHome();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    final items = PermissionService.items;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              const Text('Cấp quyền cho ứng dụng',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Smartlock cần các quyền dưới đây để kết nối và điều khiển khóa.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: SettingGroup(children: [
                    for (var i = 0; i < items.length; i++)
                      _row(items[i], _granted[i]),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              if (_needSettings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Một số quyền đã bị từ chối hẳn. Hãy mở Cài đặt và bật thủ công.',
                    style: TextStyle(
                        color: AppColors.red.withAlpha(220), fontSize: 14),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _busy || _all
                      ? (_all ? _next : null)
                      : (_needSettings ? openAppSettings : _grantAll),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _all
                        ? 'Tiếp tục'
                        : (_needSettings ? 'Mở Cài đặt' : 'Cấp tất cả quyền'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              if (!_all)
                Center(
                  child: TextButton(
                    onPressed: _next,
                    child: const Text('Để sau',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(AppPermission p, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF2E2E32)),
            child: Icon(p.icon, color: AppColors.blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(p.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? const Icon(Icons.check_circle, color: AppColors.green)
              : const Icon(Icons.radio_button_unchecked,
                  color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
