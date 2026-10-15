import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';
import '../widgets/paged_list.dart';

/// Lịch sử ra vào. [device] = null: của tất cả khóa.
class HistoryScreen extends StatelessWidget {
  final LockDevice? device;

  const HistoryScreen({super.key, this.device});

  IconData _icon(String m) => switch (m) {
        'RFID' => Icons.nfc,
        'PIN' => Icons.pin_outlined,
        'FACE' => Icons.face_outlined,
        'BLE' => Icons.bluetooth,
        'NFC_PHONE' => Icons.phone_android,
        _ => Icons.touch_app_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TitleBar(title: 'Lịch sử', onBack: () => Navigator.pop(context)),
            Expanded(
              child: PagedList<AccessEventInfo>(
                fetch: (p) => SmartlockApi.history(deviceId: device?.id, page: p),
                emptyText: 'Chưa có lượt ra vào nào.',
                itemBuilder: (context, e, _) => ListCard(
                  leading: iconBadge(_icon(e.method),
                      color: e.success ? AppColors.green : AppColors.red),
                  title: e.success
                      ? '${e.methodLabel}${e.who.isNotEmpty ? ' · ${e.who}' : ''}'
                      : '${e.methodLabel} thất bại',
                  subtitle:
                      '${fmtTime(e.createdAt)}${device == null ? ' · ${e.deviceName}' : ''}${e.reason.isNotEmpty ? ' · ${e.reason}' : ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
