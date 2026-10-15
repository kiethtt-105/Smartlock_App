import 'package:flutter/material.dart';

import '../theme.dart';

/// Thanh tiêu đề: nút back trái, tiêu đề giữa, action phải.
class TitleBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const TitleBar({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
            ),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (trailing != null)
            Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

/// Nhóm các dòng cài đặt trong 1 thẻ bo góc, tự chèn đường kẻ giữa các dòng.
class SettingGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(const Divider(
            height: 1, thickness: 1, indent: 20, color: AppColors.divider));
      }
      items.add(children[i]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: AppColors.card,
        child: SizedBox(
          width: double.infinity,
          child: Column(children: items),
        ),
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  final String title;
  final String? value;
  final bool showChevron;
  final VoidCallback? onTap;

  const SettingRow({
    super.key,
    required this.title,
    this.value,
    this.showChevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 17)),
            ),
            if (value != null)
              Text(value!,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 16)),
            if (showChevron)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class SettingSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 17)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.blue,
            inactiveTrackColor: const Color(0xFF3A3A3E),
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

class DangerButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const DangerButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

/// Hộp loading kiểu "Đang cố lấy trạng thái khóa". Đặt trong Stack, phủ lên màn hình.
class LoadingOverlay extends StatelessWidget {
  final String? text;

  const LoadingOverlay({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ModalBarrier(dismissible: false, color: Colors.black38),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                if (text != null) ...[
                  const SizedBox(height: 24),
                  Text(text!,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 17)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
