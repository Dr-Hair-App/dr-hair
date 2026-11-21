import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/api_response_cache.dart';
import '../models/review_model.dart';

class _ReviewCacheEntry {
  final List<ReviewModel> items;
  final DateTime expiresAt;

  _ReviewCacheEntry(this.items, Duration ttl)
    : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ReviewRemoteDataSource {
  final Dio _dio;
  final bool _isCustomDio;
  final ApiResponseCache _persistentCache;

  static const Duration _cacheTtl = Duration(minutes: 5);
  static final Map<String, _ReviewCacheEntry> _sharedCache = {};
  final Map<String, _ReviewCacheEntry> _instanceCache = {};

  Map<String, _ReviewCacheEntry> get _cache =>
      _isCustomDio ? _instanceCache : _sharedCache;

  ReviewRemoteDataSource({Dio? dio})
    : _dio = dio ?? DioClient(baseUrl: ApiEndpoints.backendBaseUrl).dio,
      _isCustomDio = dio != null,
      _persistentCache = ApiResponseCache();

  void clear() {
    _instanceCache.clear();
    _sharedCache.clear();
  }

  static void clearCache() {
    _sharedCache.clear();
    ApiResponseCache().clear(namespace: 'reviews');
  }

  Future<List<ReviewModel>> getReviews({String? category, int? page}) async {
    final key = '${category?.trim().toLowerCase() ?? 'all'}|${page ?? 1}';
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.items;
    }

    final cacheKey = 'reviews:list:$key';
    List<ReviewModel>? stale;
    if (!_isCustomDio) {
      final record = _persistentCache.read(cacheKey, ttl: _cacheTtl);
      final raw = record?['data'];
      if (raw is List) {
        stale = raw
            .whereType<Map>()
            .map(
              (item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
        if (record?['is_fresh'] == true) {
          _cache[key] = _ReviewCacheEntry(stale, _cacheTtl);
          return stale;
        }
      }
    }

    return _persistentCache.singleFlight(cacheKey, () async {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiEndpoints.reviewsGet,
          queryParameters: {
            if (category != null && category != 'All') 'category': category,
            'page': ?page,
          },
          options: Options(extra: const {'silent': true}),
        );

        final data = response.data?['data'];
        final rawList = data is List
            ? data
            : data is Map && data['items'] is List
            ? data['items'] as List
            : null;

        if (rawList == null) {
          throw const FormatException('Review response is invalid.');
        }

        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map(ReviewModel.fromJson)
            .where(
              (review) =>
                  review.id.isNotEmpty &&
                  review.name.trim().isNotEmpty &&
                  review.rating > 0 &&
                  review.comment.trim().isNotEmpty &&
                  review.verified,
            )
            .toList();
        _cache[key] = _ReviewCacheEntry(items, _cacheTtl);
        if (!_isCustomDio) {
          await _persistentCache.write(
            cacheKey,
            items.map((item) => item.toJson()).toList(growable: false),
          );
        }
        return items;
      } catch (_) {
        if (stale != null) return stale;
        rethrow;
      }
    });
  }
}
