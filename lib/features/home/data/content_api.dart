import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/api_response_cache.dart';

class ContentItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String content;
  final String imageUrl;
  final String actionUrl;
  final String placement;
  final String status;
  final String? approvedBy;

  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
    this.content = '',
    this.imageUrl = '',
    this.actionUrl = '',
    this.placement = 'home',
    this.status = 'published',
    this.approvedBy,
  });

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final prov = json['provenance'] is Map
        ? json['provenance'] as Map
        : const {};
    return ContentItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'tip',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      actionUrl: json['actionUrl']?.toString() ?? '',
      placement: json['placement']?.toString() ?? 'home',
      status: json['status']?.toString() ?? 'published',
      approvedBy: prov['approved_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'content': content,
    'imageUrl': imageUrl,
    'actionUrl': actionUrl,
    'placement': placement,
    'status': status,
    if (approvedBy != null) 'provenance': {'approved_by': approvedBy},
  };
}

class _ContentCacheEntry {
  final List<ContentItem> items;
  final DateTime expiresAt;

  _ContentCacheEntry(this.items, Duration ttl)
    : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ContentApi {
  final Dio _dio;
  final bool _usePersistentCache;
  final ApiResponseCache _persistentCache;

  static const Duration _cacheTtl = Duration(minutes: 20);
  static final Map<String, _ContentCacheEntry> _cache = {};

  ContentApi({Dio? dio})
    : _dio = dio ?? DioClient(baseUrl: ApiEndpoints.backendBaseUrl).dio,
      _usePersistentCache = dio == null,
      _persistentCache = ApiResponseCache();

  static void clearCache() {
    _cache.clear();
    ApiResponseCache().clear(namespace: 'home_content');
  }

  Future<List<ContentItem>> getPublishedContent({
    String? type,
    List<String>? types,
    String? placement,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final normalizedTypes = types == null
        ? ''
        : (types.map((value) => value.trim().toLowerCase()).toList()..sort())
              .join(',');
    final key =
        '${type?.trim().toLowerCase() ?? normalizedTypes}|${placement?.trim().toLowerCase() ?? 'all'}|${limit ?? 'default'}';
    if (!forceRefresh) {
      final cached = _cache[key];
      if (cached != null && !cached.isExpired) {
        return cached.items;
      }
    }

    final persistentKey = 'home_content:$key';
    List<ContentItem>? staleItems;
    if (_usePersistentCache) {
      final cached = _persistentCache.read(persistentKey, ttl: _cacheTtl);
      if (cached != null) {
        final raw = cached['data'];
        if (raw is List) {
          staleItems = raw
              .whereType<Map>()
              .map(
                (item) => ContentItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(growable: false);
          if (cached['is_fresh'] == true && !forceRefresh) {
            _cache[key] = _ContentCacheEntry(staleItems, _cacheTtl);
            return staleItems;
          }
        }
      }
    }

    return _persistentCache.singleFlight(persistentKey, () async {
      try {
        final items = await _fetchPublishedContent(
          type: type,
          types: types,
          placement: placement,
          limit: limit,
        );
        _cache[key] = _ContentCacheEntry(items, _cacheTtl);
        if (_usePersistentCache) {
          await _persistentCache.write(
            persistentKey,
            items.map((item) => item.toJson()).toList(growable: false),
          );
        }
        return items;
      } catch (_) {
        return staleItems ?? const <ContentItem>[];
      }
    });
  }

  Future<List<ContentItem>> _fetchPublishedContent({
    String? type,
    List<String>? types,
    String? placement,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{};
    if (type != null) queryParams['type'] = type;
    if (types != null && types.isNotEmpty) {
      queryParams['types'] = types.join(',');
    }
    if (placement != null) queryParams['placement'] = placement;
    if (limit != null) queryParams['limit'] = limit;

    try {
      final response = await _dio.get(
        ApiEndpoints.content,
        queryParameters: queryParams,
      );

      final data = response.data;
      final rawItems = data is Map && data['data'] is List
          ? data['data'] as List
          : data is List
          ? data
          : const [];

      final items = rawItems
          .whereType<Map<String, dynamic>>()
          .map(ContentItem.fromJson)
          .toList();
      return items;
    } catch (_) {
      rethrow;
    }
  }
}
