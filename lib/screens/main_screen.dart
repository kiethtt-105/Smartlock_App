import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../nav.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'app_settings_screen.dart';
import 'audit_screen.dart';
import 'claim_device_screen.dart';
import 'cards_screen.dart';
import 'lock_detail_screen.dart';
import 'notifications_screen.dart';
import 'shares_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AppState.instance.refreshAll();
    // Tự làm mới danh sách khóa mỗi 10 giây khi đang mở app.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      AppState.instance.refreshDevices(silent: true);
      AppState.instance.refreshUnread();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _tab == 0 ? const _DevicesTab() : const _MineTab()),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _BottomPill(selected: _tab, onSelect: (i) => setState(() => _tab = i)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Tab "Thiết bị" ─────────────────────────

class _DevicesTab extends StatefulWidget {
  const _DevicesTab();

  @override
  State<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<_DevicesTab> {
  bool _searching = false;
  String _q = '';

  Future<void> _add() async {
    await pushPage(context, const ClaimDeviceScreen());
    AppState.instance.refreshDevices(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final st = AppState.instance;
        final all = st.devices;
        final locks = _q.isEmpty
            ? all
            : all.where((d) => d.name.toLowerCase().contains(_q.toLowerCase())).toList();

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8C7A6B), Color(0xFFA9A2A0), Color(0xFF3B3B45)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_searching)
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            onChanged: (v) => setState(() => _q = v),
                            decoration: const InputDecoration(
                              hintText: 'Tìm khóa theo tên',
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        )
                      else ...[
                        const Icon(Icons.vpn_key_outlined, color: AppColors.blue, size: 34),
                        const SizedBox(width: 10),
                        const Text('Smartlock',
                            style: TextStyle(
                                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const Spacer(),
                      ],
                      _RoundIconButton(
                        icon: _searching ? Icons.close : Icons.search,
                        onTap: () => setState(() {
                          _searching = !_searching;
                          if (!_searching) _q = '';
                        }),
                      ),
                      const SizedBox(width: 10),
                      _RoundIconButton(icon: Icons.add, onTap: _add),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Tất cả(${locks.length})',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => AppState.instance.refreshDevices(silent: true),
                      child: _body(st, locks),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(AppState st, List<LockDevice> locks) {
    if (st.loadingDevices && st.devices.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Colors.white))),
      ]);
    }
    if (st.devicesError != null && st.devices.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 60),
        Text(st.devicesError!,
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
        TextButton(onPressed: st.refreshDevices, child: const Text('Thử lại')),
      ]);
    }
    if (locks.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        Text('Chưa có khóa nào.\nBấm dấu + để thêm khóa vào tài khoản.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
      ]);
    }
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: locks.length,
      itemBuilder: (context, i) {
        final lock = locks[i];
        return _LockCard(
          lock: lock,
          onTap: () async {
            await pushPage(context, LockDetailScreen(device: lock));
            AppState.instance.refreshDevices(silent: true);
          },
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF6B6561),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 54, height: 54, child: Icon(icon, color: Colors.white)),
      ),
    );
  }
}

class _LockCard extends StatelessWidget {
  final LockDevice lock;
  final VoidCallback onTap;

  const _LockCard({required this.lock, required this.onTap});

  Widget _badge(IconData icon, Color color) => Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
        child: Icon(icon, color: color, size: 18),
      );

  @override
  Widget build(BuildContext context) {
    final locked = lock.lockState == 'locked';
    final unlocked = lock.lockState == 'unlocked';
    final lockIcon = locked ? Icons.lock_outline : (unlocked ? Icons.lock_open : Icons.help_outline);
    final lockColor = unlocked ? AppColors.green : AppColors.blue;
    final batt = lock.battery;
    final battColor = (batt != null && batt < 20) ? AppColors.red : AppColors.green;

    final sub = [
      if (!lock.isOwner) 'Được chia sẻ',
      lock.isOnline ? 'Online' : 'Offline',
    ].join(' · ');

    return Material(
      color: const Color(0xFF625D5A),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _badge(lockIcon, lockColor),
                  const Spacer(),
                  if (batt != null)
                    Text('$batt%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(width: 6),
                  _badge(Icons.battery_full, battColor),
                ],
              ),
              const Spacer(),
              Text(lock.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              Text(sub, style: const TextStyle(color: Color(0xFFB9B3AF), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Tab "Của tôi" ─────────────────────────

class _MineTab extends StatelessWidget {
  const _MineTab();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final user = AppState.instance.user;
        final unread = AppState.instance.unread;
        return Container(
          color: AppColors.bg,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Material(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => pushPage(context, const AccountScreen()),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: AppColors.blue),
                              child: Text(
                                (user?.initials.isNotEmpty ?? false) ? user!.initials : '?',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user?.displayName ?? '...',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600)),
                                  Text(user?.email ?? '',
                                      style: const TextStyle(
                                          color: AppColors.textSecondary, fontSize: 15)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SettingGroup(children: [
                    SettingRow(
                      title: 'Khóa được chia sẻ với tôi',
                      onTap: () => pushPage(context, const IncomingSharesScreen()),
                    ),
                    SettingRow(
                      title: 'Thẻ NFC',
                      onTap: () => pushPage(context, const CardsScreen()),
                    ),
                    SettingRow(
                      title: 'Thông báo',
                      value: unread > 0 ? '$unread mới' : null,
                      onTap: () async {
                        await pushPage(context, const NotificationsScreen());
                        AppState.instance.refreshUnread();
                      },
                    ),
                    SettingRow(
                      title: 'Nhật ký hệ thống',
                      onTap: () => pushPage(context, const AuditScreen()),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  SettingGroup(children: [
                    SettingRow(
                      title: 'Cài đặt',
                      onTap: () => pushPage(context, const AppSettingsScreen()),
                    ),
                  ]),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── Thanh điều hướng dạng viên thuốc ─────────────────────────

class _BottomPill extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _BottomPill({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xE62F2F36),
        borderRadius: BorderRadius.circular(36),
      ),
      child: Row(
        children: [
          _item('Thiết bị', Icons.home_outlined, selected == 0, () => onSelect(0)),
          _item('Của tôi', Icons.person_outline, selected == 1, () => onSelect(1)),
        ],
      ),
    );
  }

  Widget _item(String label, IconData icon, bool active, VoidCallback onTap) {
    final color = active ? AppColors.blue : Colors.white;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
