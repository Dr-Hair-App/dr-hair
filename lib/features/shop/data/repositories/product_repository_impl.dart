import '../../domain/repositories/product_repository.dart';
import '../../../../core/storage/api_response_cache.dart';
import '../datasources/product_remote_data_source.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class _ProductCacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _ProductCacheEntry(this.data, Duration ttl)
    : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource _remoteDataSource;
  final bool _usePersistentCache;
  final ApiResponseCache _persistentCache;

  static const Duration _categoriesTtl = Duration(minutes: 15);
  static const Duration _catalogPageTtl = Duration(minutes: 5);
  static const Duration _productDetailTtl = Duration(minutes: 5);

  static final Map<String, _ProductCacheEntry<List<CategoryItem>>>
  _categoriesCache = {};
  static final Map<
    String,
    _ProductCacheEntry<({List<ProductItem> items, bool hasMore, int total})>
  >
  _catalogCache = {};
  static final Map<String, _ProductCacheEntry<ProductItem?>>
  _productDetailCache = {};

  ProductRepositoryImpl({ProductRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? ProductRemoteDataSource(),
      _usePersistentCache = remoteDataSource == null,
      _persistentCache = ApiResponseCache();

  static void clearCache() {
    _categoriesCache.clear();
    _catalogCache.clear();
    _productDetailCache.clear();
    ApiResponseCache().clear(namespace: 'products');
  }

  String _buildCatalogKey({
    String? category,
    String? rootCause,
    String? query,
    required int page,
    required int limit,
  }) =>
      '${category?.trim().toLowerCase() ?? ''}|${rootCause?.trim().toLowerCase() ?? ''}|${query?.trim().toLowerCase() ?? ''}|$page|$limit';

  @override
  Future<({List<ProductItem> items, bool hasMore, int total})> getProducts({
    String? category,
    String? rootCause,
    String? query,
    int page = 1,
    int limit = 16,
    bool forceRefresh = false,
  }) async {
    final key = _buildCatalogKey(
      category: category,
      rootCause: rootCause,
      query: query,
      page: page,
      limit: limit,
    );

    if (!forceRefresh) {
      final cached = _catalogCache[key];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    final cacheKey = 'products:catalog:$key';
    ({List<ProductItem> items, bool hasMore, int total})? stale;
    if (_usePersistentCache) {
      final cached = _persistentCache.read(cacheKey, ttl: _catalogPageTtl);
      stale = _readCatalogPayload(cached?['data']);
      if (stale != null && cached?['is_fresh'] == true && !forceRefresh) {
        _catalogCache[key] = _ProductCacheEntry(stale, _catalogPageTtl);
        return stale;
      }
    }

    return _persistentCache.singleFlight(cacheKey, () async {
      try {
        final result = await _remoteDataSource.fetchProducts(
          category: category,
          rootCause: rootCause,
          query: query,
          page: page,
          limit: limit,
        );
        _catalogCache[key] = _ProductCacheEntry(result, _catalogPageTtl);
        if (_usePersistentCache) {
          await _persistentCache.write(cacheKey, {
            'items': result.items.map((item) => item.toJson()).toList(),
            'has_more': result.hasMore,
            'total': result.total,
          });
        }
        return result;
      } catch (_) {
        if (stale != null) return stale;
        rethrow;
      }
    });
  }

  ({List<ProductItem> items, bool hasMore, int total})? _readCatalogPayload(
    dynamic raw,
  ) {
    if (raw is! Map || raw['items'] is! List) return null;
    try {
      final items = (raw['items'] as List)
          .whereType<Map>()
          .map((item) => ProductItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      return (
        items: items,
        hasMore: raw['has_more'] == true,
        total: (raw['total'] as num?)?.toInt() ?? items.length,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ProductItem?> getProductById(
    String id, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _productDetailCache[id];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    final cacheKey = 'products:detail:${id.trim()}';
    ProductItem? stale;
    if (_usePersistentCache) {
      final cached = _persistentCache.read(cacheKey, ttl: _productDetailTtl);
      final raw = cached?['data'];
      if (raw is Map) {
        try {
          stale = ProductItem.fromJson(Map<String, dynamic>.from(raw));
          if (cached?['is_fresh'] == true && !forceRefresh) {
            _productDetailCache[id] = _ProductCacheEntry(
              stale,
              _productDetailTtl,
            );
            return stale;
          }
        } catch (_) {
          stale = null;
        }
      }
    }

    return _persistentCache.singleFlight(cacheKey, () async {
      try {
        final item = await _remoteDataSource.fetchProductById(id);
        if (item != null) {
          _productDetailCache[id] = _ProductCacheEntry(item, _productDetailTtl);
          if (_usePersistentCache) {
            await _persistentCache.write(cacheKey, item.toJson());
          }
          return item;
        }
        return stale;
      } catch (_) {
        return stale;
      }
    });
  }

  @override
  Future<List<CategoryItem>> getCategories({
    String? type,
    bool forceRefresh = false,
  }) async {
    final key = type?.trim().toLowerCase() ?? 'all';
    if (!forceRefresh) {
      final cached = _categoriesCache[key];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    final cacheKey = 'products:categories:$key';
    List<CategoryItem>? stale;
    if (_usePersistentCache) {
      final cached = _persistentCache.read(cacheKey, ttl: _categoriesTtl);
      final raw = cached?['data'];
      if (raw is List) {
        stale = raw
            .whereType<Map>()
            .map(
              (item) => CategoryItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
        if (cached?['is_fresh'] == true && !forceRefresh) {
          _categoriesCache[key] = _ProductCacheEntry(stale, _categoriesTtl);
          return stale;
        }
      }
    }

    return _persistentCache.singleFlight(cacheKey, () async {
      try {
        final categories = await _remoteDataSource.fetchCategories(type: type);
        _categoriesCache[key] = _ProductCacheEntry(categories, _categoriesTtl);
        if (_usePersistentCache) {
          await _persistentCache.write(
            cacheKey,
            categories.map((item) => item.toJson()).toList(),
          );
        }
        return categories;
      } catch (_) {
        if (stale != null) return stale;
        rethrow;
      }
    });
  }
}
