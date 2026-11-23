/// The `data` and `meta` of a successful envelope.
class ApiResult {
  const ApiResult(this.data, this.meta, {this.replayed = false});

  final dynamic data;
  final Map<String, dynamic> meta;

  /// True when the ERP answered from its idempotency store (the action had already been done).
  final bool replayed;

  Map<String, dynamic> get map => data is Map ? Map<String, dynamic>.from(data as Map) : <String, dynamic>{};

  List<Map<String, dynamic>> get list =>
      data is List ? (data as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

  int get page => (meta['page'] as num?)?.toInt() ?? 1;
  int get lastPage => (meta['last_page'] as num?)?.toInt() ?? 1;
  int get total => (meta['total'] as num?)?.toInt() ?? list.length;
  bool get hasMore => page < lastPage;
}

/// A page of rows loaded so far, used by infinite lists.
class PageState<T> {
  const PageState({this.items = const [], this.page = 0, this.lastPage = 1, this.loadingMore = false, this.error});

  final List<T> items;
  final int page;
  final int lastPage;
  final bool loadingMore;
  final Object? error;

  bool get hasMore => page < lastPage;

  PageState<T> copyWith({List<T>? items, int? page, int? lastPage, bool? loadingMore, Object? error, bool clearError = false}) => PageState<T>(
        items: items ?? this.items,
        page: page ?? this.page,
        lastPage: lastPage ?? this.lastPage,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}
