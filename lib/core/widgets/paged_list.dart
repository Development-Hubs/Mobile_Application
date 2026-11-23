import 'package:flutter/material.dart';

import '../api/api_result.dart';
import '../i18n/i18n.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import 'ui.dart';

/// Loads `?page=` pages from the ERP as the person scrolls, with pull-to-refresh.
///
/// Rows are only what the server returned; an error is shown as an error, never as sample rows.
class PagedList extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.header = const [],
    this.empty,
    this.perPage = 20,
  });

  final Future<ApiResult> Function(int page, int perPage) fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> row, int index) itemBuilder;
  final List<Widget> header;
  final Widget? empty;
  final int perPage;

  @override
  State<PagedList> createState() => PagedListState();
}

class PagedListState extends State<PagedList> {
  PageState<Map<String, dynamic>> _s = const PageState();
  bool _loading = true;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _more();
    });
    reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      _loading = _s.items.isEmpty;
      _s = _s.copyWith(clearError: true);
    });
    try {
      final r = await widget.fetch(1, widget.perPage);
      if (!mounted) return;
      setState(() => _s = PageState(items: r.list, page: r.page, lastPage: r.lastPage));
    } catch (e) {
      if (mounted) setState(() => _s = _s.copyWith(error: e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    if (_s.loadingMore || !_s.hasMore || _s.error != null) return;
    setState(() => _s = _s.copyWith(loadingMore: true));
    try {
      final r = await widget.fetch(_s.page + 1, widget.perPage);
      if (!mounted) return;
      setState(() => _s = PageState(items: [..._s.items, ...r.list], page: r.page, lastPage: r.lastPage));
    } catch (e) {
      if (mounted) setState(() => _s = _s.copyWith(loadingMore: false, error: e));
    }
  }

  /// Replaces one row in place after an action confirmed by the server.
  void replace(bool Function(Map<String, dynamic>) test, Map<String, dynamic> row) {
    setState(() => _s = _s.copyWith(items: [for (final r in _s.items) test(r) ? {...r, ...row} : r]));
  }

  void remove(bool Function(Map<String, dynamic>) test) => setState(() => _s = _s.copyWith(items: _s.items.where((r) => !test(r)).toList()));

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ...widget.header,
      if (_loading)
        const SkeletonList()
      else if (_s.items.isEmpty && _s.error != null)
        ErrorView(error: _s.error!, onRetry: reload)
      else if (_s.items.isEmpty)
        widget.empty ?? EmptyView(title: context.tr('empty'))
      else ...[
        for (final (i, row) in _s.items.indexed) Reveal(index: i % 12, child: widget.itemBuilder(context, row, i)),
        if (_s.loadingMore) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        if (_s.error != null && _s.items.isNotEmpty) Center(child: TextButton.icon(onPressed: _more, icon: const Icon(Icons.refresh_rounded), label: Text(context.tr('retry')))),
      ],
      const SizedBox(height: 120),
    ];
    return RefreshIndicator(
      color: Palette.maroon,
      onRefresh: reload,
      child: ListView(controller: _scroll, padding: EdgeInsets.zero, physics: const AlwaysScrollableScrollPhysics(), children: children),
    );
  }
}
