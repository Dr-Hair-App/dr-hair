import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_local_cache.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/repositories/product_repository.dart';
import 'products_state.dart';

class ProductsCubit extends Cubit<ProductsState> {
  static const int pageSize = 16;
  static const String _categoriesCacheKey = 'cache_product_categories_v2';
  static const String _productsCachePrefix =
      '${AppLocalCache.productCatalogCachePrefix}v2_';

  final ProductRepository _repository;
  final AppLocalCache _cache;
  Future<void>? _categoriesLoad;
  Timer? _searchDebounce;
  final Map<String, Future<void>> _pendingPageLoads = {};
  final Set<String> _freshPageKeys = {};

  ProductsCubit({
    ProductRepository? repository,
    ProductsState? initialState,
    AppLocalCache? cache,
  }) : _repository = repository ?? ProductRepositoryImpl(),
       _cache = cache ?? AppLocalCache.instance,
       super(initialState ?? ProductsState.initial());

  String _categoryIdForIndex(int index) {
    if (index >= 0 && index < state.categories.length) {
      final id = state.categories[index].id.trim().toLowerCase();
      if (id.isNotEmpty && id != 'all') return id;
    }
    return 'all';
  }

  String _catalogKey(String categoryId, String query) =>
      '${categoryId.trim().toLowerCase()}|${query.trim().toLowerCase()}';

  String _pageCacheKey(String catalogKey, int page) =>
      '$_productsCachePrefix${Uri.encodeComponent(catalogKey)}_page_$page';

  Future<void> _ensureCategories() {
    if (_categoriesLoad != null) return _categoriesLoad!;
    if (state.categories.length > 1) return Future<void>.value();

    final request = _loadCategories();
    _categoriesLoad = request;
    return request;
  }

  Future<void> _loadCategories() async {
    final cached = _cache.getJson(_categoriesCacheKey);
    if (cached is List) {
      final categories = _parseCategories(cached);
      if (categories.isNotEmpty) {
        emit(state.copyWith(categories: _withAllCategory(categories)));
      }
    }

    try {
      final fetched = await _repository.getCategories();
      if (isClosed) return;
      final categories = _withAllCategory(fetched);
      emit(state.copyWith(categories: categories));
      if (categories.isNotEmpty) {
        await _cache.putJson(
          _categoriesCacheKey,
          categories.map((category) => category.toJson()).toList(),
        );
      }
    } catch (_) {
      // Keep last known Hive categories or the built-in All tab available.
      if (!isClosed && state.categories.isEmpty) {
        emit(
          state.copyWith(categories: CategoryItem.defaultProductCategories()),
        );
      }
    }
  }

  List<CategoryItem> _parseCategories(List<dynamic> raw) {
    try {
      return raw
          .whereType<Map>()
          .map(
            (value) => CategoryItem.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false);
    } catch (_) {
      return const <CategoryItem>[];
    }
  }

  List<CategoryItem> _withAllCategory(List<CategoryItem> categories) {
    if (categories.any(
      (category) => category.id.trim().toLowerCase() == 'all',
    )) {
      return categories;
    }
    return [...CategoryItem.defaultProductCategories(), ...categories];
  }

  /// Shows Hive immediately, then fetches and replaces the selected catalog's
  /// first page once for this screen session. The server page size is capped at
  /// 16 even if an older caller passes a larger limit.
  Future<void> loadProducts({
    bool refresh = false,
    int limit = pageSize,
  }) async {
    final categoriesLoad = _ensureCategories();
    final categoryId = _categoryIdForIndex(state.selectedCategoryIndex);
    final query = state.searchQuery.trim();
    final safeLimit = limit.clamp(1, pageSize).toInt();

    await _loadCatalogPage(
      categoryId: categoryId,
      query: query,
      page: 1,
      limit: safeLimit,
      refresh: refresh,
    );
    await categoriesLoad;
  }

  Future<void> _loadCatalogPage({
    required String categoryId,
    required String query,
    required int page,
    required int limit,
    bool refresh = false,
  }) async {
    final catalogKey = _catalogKey(categoryId, query);
    final pageKey = '$catalogKey#$page';
    if (!refresh && _freshPageKeys.contains(pageKey)) return;

    if (!refresh) {
      final cached = _readCachedPage(catalogKey, page, limit);
      if (cached != null) {
        _applyPage(
          catalogKey: catalogKey,
          page: page,
          items: cached.items,
          hasMore: cached.hasMore,
          total: cached.total,
          replace: page == 1,
          isLoading: !_freshPageKeys.contains(pageKey),
          isLoadingMore: false,
        );
      }
    }

    final pending = _pendingPageLoads[pageKey];
    if (pending != null) return pending;
    if (!isClosed &&
        state.selectedCategoryId == categoryId &&
        state.searchQuery.trim() == query.trim()) {
      emit(
        state.copyWith(
          isLoading: page == 1,
          isLoadingMore: page > 1,
          errorMessage: null,
        ),
      );
    }

    final request = _fetchAndCachePage(
      catalogKey: catalogKey,
      categoryId: categoryId,
      query: query,
      page: page,
      limit: limit,
      pageKey: pageKey,
    );
    _pendingPageLoads[pageKey] = request;
    try {
      await request;
    } finally {
      _pendingPageLoads.remove(pageKey);
    }
  }

  Future<void> _fetchAndCachePage({
    required String catalogKey,
    required String categoryId,
    required String query,
    required int page,
    required int limit,
    required String pageKey,
  }) async {
    try {
      final result = await _repository.getProducts(
        rootCause: categoryId == 'all' ? null : categoryId,
        query: query,
        page: page,
        limit: limit,
      );
      if (isClosed) return;

      final existing =
          state.productsByCatalog[catalogKey] ?? const <ProductItem>[];
      final retainedPages = page == 1
          ? const <ProductItem>[]
          : existing.take((page - 1) * limit).toList(growable: false);
      final items = page == 1
          ? result.items
          : _appendUnique(retainedPages, result.items);
      final hasMore = result.hasMore && result.items.length == limit;
      _freshPageKeys.add(pageKey);
      _applyPage(
        catalogKey: catalogKey,
        page: page,
        items: items,
        hasMore: hasMore,
        total: result.total,
        replace: true,
        isLoading: false,
        isLoadingMore: false,
      );

      ProductItem.cacheProducts(result.items);
      await _cache.putJson(_pageCacheKey(catalogKey, page), {
        'items': result.items.map((item) => item.toJson()).toList(),
        'has_more': hasMore,
        'total': result.total,
      });
    } catch (_) {
      if (isClosed) return;
      if (state.selectedCategoryId == categoryId &&
          state.searchQuery.trim() == query.trim()) {
        emit(
          state.copyWith(
            isLoading: false,
            isLoadingMore: false,
            errorMessage: state.productsFor(categoryId, query).isEmpty
                ? 'Unable to load products. Please check your connection.'
                : 'Could not refresh products. Showing saved results.',
          ),
        );
      }
      // Keep the cached page visible if refresh fails.
    }
  }

  ({List<ProductItem> items, bool hasMore, int total})? _readCachedPage(
    String catalogKey,
    int page,
    int limit,
  ) {
    final raw = _cache.getJson(_pageCacheKey(catalogKey, page));
    if (raw is! Map || raw['items'] is! List) return null;
    try {
      final items = (raw['items'] as List)
          .whereType<Map>()
          .map(
            (value) => ProductItem.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false);
      return (
        items: items,
        hasMore: raw['has_more'] == true && items.length == limit,
        total: (raw['total'] as num?)?.toInt() ?? items.length,
      );
    } catch (_) {
      return null;
    }
  }

  void _applyPage({
    required String catalogKey,
    required int page,
    required List<ProductItem> items,
    required bool hasMore,
    required int total,
    required bool replace,
    required bool isLoading,
    required bool isLoadingMore,
  }) {
    final productsByCatalog = Map<String, List<ProductItem>>.from(
      state.productsByCatalog,
    );
    final hasMoreByCatalog = Map<String, bool>.from(state.hasMoreByCatalog);
    final pageByCatalog = Map<String, int>.from(state.pageByCatalog);
    final totalByCatalog = Map<String, int>.from(state.totalByCatalog);
    final visibleItems = replace
        ? items
        : _appendUnique(productsByCatalog[catalogKey] ?? const [], items);
    productsByCatalog[catalogKey] = visibleItems;
    hasMoreByCatalog[catalogKey] = hasMore;
    pageByCatalog[catalogKey] = page;
    totalByCatalog[catalogKey] = total;

    final shouldUpdateVisible =
        state.catalogKey(state.selectedCategoryId) == catalogKey;
    emit(
      state.copyWith(
        products: shouldUpdateVisible ? visibleItems : null,
        productsByCatalog: productsByCatalog,
        hasMoreByCatalog: hasMoreByCatalog,
        pageByCatalog: pageByCatalog,
        totalByCatalog: totalByCatalog,
        isLoading: shouldUpdateVisible ? isLoading : state.isLoading,
        isLoadingMore: shouldUpdateVisible
            ? isLoadingMore
            : state.isLoadingMore,
        errorMessage: null,
      ),
    );
  }

  List<ProductItem> _appendUnique(
    List<ProductItem> current,
    List<ProductItem> incoming,
  ) {
    final result = List<ProductItem>.of(current);
    final seen = result.map((item) => item.id).toSet();
    for (final item in incoming) {
      if (seen.add(item.id)) result.add(item);
    }
    return result;
  }

  Future<void> selectCategory(int index) async {
    await _ensureCategories();
    if (isClosed || index < 0 || index >= state.categories.length) return;
    if (index == state.selectedCategoryIndex) return;

    final categoryId = _categoryIdForIndex(index);
    final query = state.searchQuery.trim();
    final catalogKey = _catalogKey(categoryId, query);
    final cachedItems =
        state.productsByCatalog[catalogKey] ?? const <ProductItem>[];
    emit(
      state.copyWith(
        selectedCategoryIndex: index,
        products: cachedItems,
        isLoading: cachedItems.isEmpty,
        isLoadingMore: false,
        errorMessage: null,
      ),
    );
    await _loadCatalogPage(
      categoryId: categoryId,
      query: query,
      page: 1,
      limit: pageSize,
    );
  }

  Future<void> loadNextPage(String categoryId, {String? query}) async {
    final cleanQuery = (query ?? state.searchQuery).trim();
    final key = _catalogKey(categoryId, cleanQuery);
    if (state.hasMoreByCatalog[key] != true) return;
    final nextPage = (state.pageByCatalog[key] ?? 1) + 1;
    await _loadCatalogPage(
      categoryId: categoryId,
      query: cleanQuery,
      page: nextPage,
      limit: pageSize,
    );
  }

  Future<void> search(String query) async {
    _searchDebounce?.cancel();
    final cleanQuery = query.trim();
    final categoryId = state.selectedCategoryId;
    final cached =
        state.productsByCatalog[_catalogKey(categoryId, cleanQuery)] ??
        const <ProductItem>[];
    emit(
      state.copyWith(
        searchQuery: cleanQuery,
        products: cached,
        isLoading: cached.isEmpty,
        isLoadingMore: false,
        errorMessage: null,
      ),
    );
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!isClosed) {
        unawaited(
          _loadCatalogPage(
            categoryId: state.selectedCategoryId,
            query: state.searchQuery,
            page: 1,
            limit: pageSize,
          ),
        );
      }
    });
  }

  Future<void> clearSearch() => search('');

  Future<void> refreshSelectedCategory() async {
    _searchDebounce?.cancel();
    final categoryId = state.selectedCategoryId;
    final query = state.searchQuery.trim();
    final key = _catalogKey(categoryId, query);
    _freshPageKeys.removeWhere((pageKey) => pageKey.startsWith('$key#'));
    await _loadCatalogPage(
      categoryId: categoryId,
      query: query,
      page: 1,
      limit: pageSize,
      refresh: true,
    );
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
