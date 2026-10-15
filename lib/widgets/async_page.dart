import 'package:flutter/material.dart';

import '../theme.dart';
import 'common.dart';
import 'helpers.dart';

/// Màn hình tải dữ liệu 1 lần (có vòng loading, lỗi + Thử lại, kéo để làm mới).
class AsyncPage<T> extends StatefulWidget {
  final String title;
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Widget Function(BuildContext context, Future<void> Function() reload)? fab;
  final List<Widget> actions;

  const AsyncPage({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
    this.fab,
    this.actions = const [],
  });

  @override
  State<AsyncPage<T>> createState() => _AsyncPageState<T>();
}

class _AsyncPageState<T> extends State<AsyncPage<T>> {
  T? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (_data == null) setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errMsg(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading && _data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _data == null) {
      body = errorView(_error!, reload);
    } else {
      body = RefreshIndicator(
        onRefresh: reload,
        child: widget.builder(context, _data as T, reload),
      );
    }
    return Scaffold(
      floatingActionButton: widget.fab?.call(context, reload),
      body: SafeArea(
        child: Column(
          children: [
            TitleBar(
              title: widget.title,
              onBack: () => Navigator.pop(context),
              trailing: widget.actions.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: widget.actions),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Nút FAB chuẩn của app.
Widget appFab(String label, IconData icon, VoidCallback onTap) => FloatingActionButton.extended(
      onPressed: onTap,
      backgroundColor: AppColors.blue,
      foregroundColor: Colors.white,
      icon: Icon(icon),
      label: Text(label),
    );
