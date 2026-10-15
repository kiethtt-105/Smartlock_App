import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';

/// Thêm khóa vào tài khoản bằng mã khóa + secret (in trên khóa / hộp).
class ClaimDeviceScreen extends StatefulWidget {
  const ClaimDeviceScreen({super.key});

  @override
  State<ClaimDeviceScreen> createState() => _ClaimDeviceScreenState();
}

class _ClaimDeviceScreenState extends State<ClaimDeviceScreen> {
  final _code = TextEditingController();
  final _secret = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_code.text.trim().isEmpty || _secret.text.isEmpty) {
      showMsg(context, 'Hãy nhập mã khóa và secret.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final d = await SmartlockApi.claim(_code.text.trim(), _secret.text);
      await AppState.instance.refreshDevices(silent: true);
      if (!mounted) return;
      showMsg(context, 'Đã thêm khóa "${d.name}".');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitleBar(title: 'Thêm khóa', onBack: () => Navigator.pop(context)),
              const SizedBox(height: 16),
              const Text('Nhập mã khóa và secret được cấp cùng thiết bị.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              const SizedBox(height: 20),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Mã khóa (device code)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _secret,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Secret',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _busy ? null : _claim,
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
                      : const Text('Thêm khóa', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
