import 'package:flutter/material.dart';

import '../api/smartlock_api.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/async_page.dart';
import '../widgets/helpers.dart';

class FacesScreen extends StatelessWidget {
  final LockDevice device;

  const FacesScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return AsyncPage<List<FaceProfileInfo>>(
      title: 'Khuôn mặt',
      load: () => SmartlockApi.faces(device.id),
      builder: (ctx, faces, reload) {
        Future<void> run(Future<void> Function() action) async {
          try {
            await action();
            await reload();
          } catch (e) {
            if (ctx.mounted) showError(ctx, e);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Danh sách hồ sơ khuôn mặt đã đăng ký trên khóa. Đăng ký khuôn mặt mới cần '
                'camera và mô hình nhận diện, bản app này chưa hỗ trợ (đăng ký từ thiết bị có camera).',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            if (faces.isEmpty)
              SizedBox(height: 200, child: emptyView('Chưa có hồ sơ khuôn mặt.', icon: Icons.face_outlined)),
            for (final f in faces)
              ListCard(
                leading: iconBadge(Icons.face_outlined,
                    color: f.isActive ? AppColors.blue : AppColors.textSecondary),
                title: f.name.isEmpty ? f.user : f.name,
                subtitle: '${f.user}${f.isActive ? '' : ' · đã tắt'}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: f.isActive,
                      onChanged: (v) => run(() => SmartlockApi.setFaceActive(f.id, v)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.red),
                      onPressed: () async {
                        if (await confirmDialog(ctx,
                            title: 'Xóa hồ sơ khuôn mặt?',
                            text: 'Dữ liệu sinh trắc sẽ bị xóa hẳn.',
                            okText: 'Xóa',
                            danger: true)) {
                          await run(() => SmartlockApi.deleteFace(f.id));
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
