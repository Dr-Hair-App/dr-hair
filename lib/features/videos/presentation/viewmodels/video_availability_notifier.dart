import 'package:flutter/foundation.dart';

import '../../../../core/storage/app_local_cache.dart';

/// Tracks whether real patient video stories are available (non-empty and reachable).
/// Persists the last known state across app cold starts via [AppLocalCache].
class VideoAvailabilityNotifier extends ValueNotifier<bool> {
  static const String cacheKey = 'cached_has_video_stories_v1';

  VideoAvailabilityNotifier._() : super(_readInitialValue());

  static bool _readInitialValue() {
    return AppLocalCache.instance.getBool(cacheKey) ?? true;
  }

  static final VideoAvailabilityNotifier instance =
      VideoAvailabilityNotifier._();

  void updateAvailability(bool hasVideos) {
    if (value != hasVideos) {
      value = hasVideos;
      AppLocalCache.instance.put(cacheKey, hasVideos);
    }
  }

  @visibleForTesting
  void reset([bool defaultValue = true]) {
    value = defaultValue;
  }
}
