import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/helpers.dart';
import '../widgets/paged_list.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  Color _color(AuditInfo a) {
    if (!a.success || a.severity == 'critical') return AppColors.red;
    if (a.severity == 'warning') return const Color(0xFFFFB020);
    return AppColors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TitleBar(title: 'Nhật ký hệ thống', onBack: () => Navigator.pop(context)),
            Expanded(
              child: PagedList<AuditInfo>(
                fetch: (p) => SmartlockApi.audit(page: p),
                emptyText: 'Chưa có nhật ký.',
                itemBuilder: (context, a, _) => ListCard(
                  leading: iconBadge(
                      a.success ? Icons.fact_check_outlined : Icons.error_outline,
                      color: _color(a)),
                  title: a.action,
                  subtitle:
                      '${fmtTime(a.createdAt)}${a.device.isNotEmpty ? ' · ${a.device}' : ''}${a.ip.isNotEmpty ? ' · ${a.ip}' : ''}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
