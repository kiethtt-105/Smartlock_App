import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

/// Mở bảng "chạm thẻ" và trả về UID thẻ (hex IN HOA, không dấu ':' - đúng định dạng server chuẩn hoá),
/// hoặc null nếu người dùng huỷ / điện thoại không có NFC.
Future<String?> scanCardUid(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      backgroundColor: C.card2,
      isScrollControlled: true,
      builder: (_) => const _ScanSheet(),
    );

String _hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

class _ScanSheet extends StatefulWidget {
  const _ScanSheet();
  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> {
  String? _err;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    if (!kIsWeb) NfcManager.instance.stopSession().catchError((_) {});
    super.dispose();
  }

  Future<void> _start() async {
    if (kIsWeb) return _fail('Trình duyệt không hỗ trợ đọc NFC. Hãy nhập UID bằng tay.');
    try {
      if (!await NfcManager.instance.isAvailable()) {
        return _fail('Điện thoại không có NFC hoặc NFC đang tắt. Bật NFC trong Cài đặt rồi thử lại.');
      }
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          String? uid;
          if (defaultTargetPlatform == TargetPlatform.android) {
            final a = NfcTagAndroid.from(tag);
            if (a != null) uid = _hex(a.id);
          } else if (defaultTargetPlatform == TargetPlatform.iOS) {
            final m = MiFareIos.from(tag);
            if (m != null) uid = _hex(m.identifier);
          }
          await NfcManager.instance.stopSession();
          if (!mounted || _done) return;
          if (uid == null || uid.length < 4) return _fail('Không đọc được UID của thẻ này. Thử thẻ khác.');
          _done = true;
          Navigator.of(context).pop(uid);
        },
      );
    } catch (_) {
      _fail('Không bật được đọc NFC. Thử lại hoặc nhập UID bằng tay.');
    }
  }

  void _fail(String m) {
    if (mounted) setState(() => _err = m);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84, height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, color: (_err == null ? C.violet : C.red).withValues(alpha: .15)),
            child: Icon(_err == null ? Icons.nfc_rounded : Icons.error_outline_rounded,
                size: 40, color: _err == null ? C.violet : C.red),
          ),
          const SizedBox(height: 18),
          Text(_err == null ? 'Chạm thẻ vào lưng điện thoại' : 'Không quét được', style: t(19, w: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_err ?? 'Giữ thẻ yên vài giây cho tới khi app nhận được.',
              style: t(14, color: C.sub, h: 1.4), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          if (_err != null) ...[
            GradBtn('Thử lại', onTap: () {
              setState(() => _err = null);
              _start();
            }),
            const SizedBox(height: 10),
          ],
          GradBtn('Huỷ', filled: false, onTap: () => Navigator.of(context).pop()),
        ]),
      );
}
