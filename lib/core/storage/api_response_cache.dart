import 'package:flutter/foundation.dart';

import 'app_local_cache.dart';

/// Persistent JSON response cache for reference data that is safe to reuse
/// across app launches (catalogs, education content, and public reviews).
/// Patient-specific or transaction data should use patient-scoped keys and its
/// own freshness rules instead of this shared cache.
class ApiResponseCache {
  ApiResponseCache({AppLocalCache? storage})
    : _storage = storage ?? AppLocalCache.instance;

  static const String _keyPrefix = 'api_response_v1_';
  static final Map<String, Future<dynamic>> _inFlight = {};

  final AppLocalCache _storage;

  String _key(String key) {
    final separator = key.indexOf(':');
    if (separator <= 0) return '$_keyPrefix${Uri.encodeComponent(key)}';
    final namespace = key.substring(0, separator);
    final name = key.substring(separator + 1);
    return '$_keyPrefix${namespace}_${Uri.encodeComponent(name)}';
  }

  /// Returns cached JSON even when stale, so callers can keep it visible if
  /// revalidation fails. Freshness is evaluated against the endpoint's TTL.
  Map<String, dynamic>? read(String key, {required Duration ttl}) {
    final envelope = _storage.getJson(_key(key));
    if (envelope is! Map || envelope['version'] != 1) return null;
    final savedAt = envelope['saved_at_ms'];
    if (savedAt is! num || !envelope.containsKey('data')) return null;
    final savedAtTime = DateTime.fromMillisecondsSinceEpoch(savedAt.toInt());
    final age = DateTime.now().difference(savedAtTime);
    if (age.isNegative || age > const Duration(days: 14)) {
      return null;
    }
    return <String, dynamic>{'data': envelope['data'], 'is_fresh': age <= ttl};
  }

  Future<void> write(String key, Object? data) => _storage.putJson(_key(key), {
    'version': 1,
    'saved_at_ms': DateTime.now().millisecondsSinceEpoch,
    'data': data,
  });

  Future<void> clear({String? namespace}) => _storage.removeByPrefix(
    namespace == null ? _keyPrefix : '$_keyPrefix${namespace}_',
  );

  /// Coalesces simultaneous loads for the same cache key into one API request.
  Future<T> singleFlight<T>(String key, Future<T> Function() load) async {
    final cacheKey = _key(key);
    final pending = _inFlight[cacheKey];
    if (pending != null) return await pending as T;

    final request = load();
    _inFlight[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[cacheKey], request)) {
        _inFlight.remove(cacheKey);
      }
    }
  }

  @visibleForTesting
  static void clearInFlightForTesting() => _inFlight.clear();
}
