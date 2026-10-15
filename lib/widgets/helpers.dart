import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';

void showMsg(BuildContext context, String text, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? const Color(0xFF8B1A1A) : const Color(0xFF3A3A3E),
      behavior: SnackBarBehavior.floating,
    ));
}

String errMsg(Object e) => e is ApiException ? e.message : 'Có lỗi xảy ra. Vui lòng thử lại.';

void showError(BuildContext context, Object e) => showMsg(context, errMsg(e), error: true);

Future<bool> confirmDialog(BuildContext context,
    {required String title, String? text, String okText = 'Đồng ý', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: text == null ? null : Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(okText,
              style: TextStyle(color: danger ? AppColors.red : AppColors.blue)),
        ),
      ],
    ),
  );
  return r == true;
}

/// Hộp nhập 1 dòng chữ. Trả null nếu hủy.
Future<String?> promptDialog(BuildContext context,
    {required String title,
    String? hint,
    String initial = '',
    bool obscure = false,
    TextInputType? keyboard,
    String okText = 'Lưu'}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: obscure,
        keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: Text(okText, style: const TextStyle(color: AppColors.blue)),
        ),
      ],
    ),
  );
}

String fmtTime(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Thẻ nền tối bo góc cho 1 phần tử trong danh sách.
class ListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget iconBadge(IconData icon, {Color color = AppColors.blue}) => Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2E2E32)),
      child: Icon(icon, color: color, size: 22),
    );

Widget statusChip(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );

Widget emptyView(String text, {IconData icon = Icons.inbox_outlined}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      ),
    );

Widget errorView(String text, VoidCallback retry) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: retry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
