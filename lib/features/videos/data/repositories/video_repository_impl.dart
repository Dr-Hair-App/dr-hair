import '../../domain/models/video_story_model.dart';
import '../../domain/repositories/video_repository.dart';
import '../../../../core/storage/api_response_cache.dart';
import '../datasources/video_remote_data_source.dart';

class _VideoCacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _VideoCacheEntry(this.data, Duration ttl)
    : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource _remoteDataSource;
  final bool _usePersistentCache;
  final ApiResponseCache _persistentCache;

  static const Duration _cacheTtl = Duration(minutes: 5);

  static final Map<
    String,
    _VideoCacheEntry<
      ({List<VideoStoryModel> items, bool hasMore, int total, int page})
    >
  >
  _videosCache = {};
  static _VideoCacheEntry<List<String>>? _categoriesCache;

  Map<String, dynamic> _cacheableVideoJson(VideoStoryModel item) {
    final json = item.toJson();
    final uri = Uri.tryParse(item.videoUrl);
    final hasExpiringCredential =
        uri?.queryParameters.keys.any(
          (key) => RegExp(
            r'(sig|token|expires|credential)',
            caseSensitive: false,
          ).hasMatch(key),
        ) ??
        false;
    if (hasExpiringCredential) json.remove('video_url');
    return json;
  }

  VideoRepositoryImpl({VideoRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? VideoRemoteDataSource(),
      _usePersistentCache = remoteDataSource == null,
      _persistentCache = ApiResponseCache();

  static void clearCache() {
    _videosCache.clear();
    _categoriesCache = null;
    ApiResponseCache().clear(namespace: 'videos');
  }

  @override
  Future<({List<VideoStoryModel> items, bool hasMore, int total, int page})>
  getVideos({
    int page = 1,
    int limit = 10,
    String? category,
    String? placement = 'reels',
    bool forceRefresh = false,
  }) async {
    final key = '$placement|${category ?? ''}|$page|$limit';
    if (!forceRefresh) {
      final cached = _videosCache[key];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }
    }

    final cacheKey = 'videos:list:$key';
    ({List<VideoStoryModel> items, bool hasMore, int total, int page})? stale;
    if (_usePersistentCache) {
      final cached = _persistentCache.read(cacheKey, ttl: _cacheTtl);
      final raw = cached?['data'];
      if (raw is Map && raw['items'] is List) {
        try {
          stale = (
            items: (raw['items'] as List)
                .whereType<Map>()
                .map(
                  (item) =>
                      VideoStoryModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false),
            hasMore: raw['has_more'] == true,
            total: (raw['total'] as num?)?.toInt() ?? 0,
            page: (raw['page'] as num?)?.toInt() ?? page,
          );
          if (cached?['is_fresh'] == true && !forceRefresh) {
            _videosCache[key] = _VideoCacheEntry(stale, _cacheTtl);
            return stale;
          }
        } catch (_) {
          stale = null;
        }
      }
    }

    return _persistentCache.singleFlight(cacheKey, () async {
      try {
        final result = await _remoteDataSource.fetchVideos(
          page: page,
          limit: limit,
          category: category,
          placement: placement,
        );
        _videosCache[key] = _VideoCacheEntry(result, _cacheTtl);
        if (_usePersistentCache) {
          await _persistentCache.write(cacheKey, {
            'items': result.items.map(_cacheableVideoJson).toList(),
            'has_more': result.hasMore,
            'total': result.total,
            'page': result.page,
          });
        }
        return result;
      } catch (_) {
        if (stale != null) return stale;
        rethrow;
      }
    });
  }

  @override
  Future<List<String>> getVideoCategories({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _categoriesCache != null &&
        !_categoriesCache!.isExpired) {
      return _categoriesCache!.data;
    }

    const cacheKey = 'videos:categories';
    List<String>? stale;
    if (_usePersistentCache) {
      final cached = _persistentCache.read(cacheKey, ttl: _cacheTtl);
      final raw = cached?['data'];
      if (raw is List) {
        stale = raw.map((value) => value.toString()).toList(growable: false);
        if (cached?['is_fresh'] == true && !forceRefresh) {
          _categoriesCache = _VideoCacheEntry(stale, _cacheTtl);
          return stale;
        }
      }
    }

    return _persistentCache.singleFlight(cacheKey, () async {
      try {
        final categories = await _remoteDataSource.fetchVideoCategories();
        _categoriesCache = _VideoCacheEntry(categories, _cacheTtl);
        if (_usePersistentCache) {
          await _persistentCache.write(cacheKey, categories);
        }
        return categories;
      } catch (_) {
        if (stale != null) return stale;
        rethrow;
      }
    });
  }
}
