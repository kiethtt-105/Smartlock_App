import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'helpers.dart';

/// Danh sách phân trang (kéo xuống để làm mới, cuộn hết thì tự tải trang kế).
class PagedList<T> extends StatefulWidget {
  final Future<PageResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String emptyText;
  final void Function(PageResult<T> firstPage)? onFirstPage;

  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.emptyText = 'Chưa có dữ liệu.',
    this.onFirstPage,
  });

  @override
  State<PagedList<T>> createState() => PagedListState<T>();
}

class PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  int _page = 1;
  bool _hasNext = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final r = await widget.fetch(1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _page = 1;
        _hasNext = r.hasNext;
        _error = null;
        _loading = false;
      });
      widget.onFirstPage?.call(r);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errMsg(e);
        _loading = false;
      });
    }
  }

  /// Bỏ ngay phần tử khỏi danh sách (dùng với Dismissible để tránh lỗi "still part of the tree").
  void removeWhere(bool Function(T item) test) => setState(() => _items.removeWhere(test));

  Future<void> _more() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);
    try {
      final r = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(r.items);
        _page += 1;
        _hasNext = r.hasNext;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) {
      return errorView(_error!, () {
        setState(() => _loading = true);
        reload();
      });
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: _items.isEmpty
          ? ListView(children: [
              SizedBox(height: 120, child: emptyView(widget.emptyText)),
            ])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: _items.length + (_hasNext ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  _more();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
                      ),
                    ),
                  );
                }
                return widget.itemBuilder(context, _items[i], reload);
              },
            ),
    );
  }
}
