import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/app_local_cache.dart';
import '../presentation/viewmodels/app_config_state.dart';

class AppConfigBundle {
  final Map<String, bool> features;
  final AppointmentBillingConfig appointmentBilling;
  final AppVersionCheck versionCheck;

  const AppConfigBundle({
    required this.features,
    required this.appointmentBilling,
    this.versionCheck = const AppVersionCheck(),
  });
}

/// Repository that handles fetching, caching, and serving live app feature flags.
class AppConfigRepository {
  final DioClient _dioClient;
  final AppLocalCache _cache;

  AppConfigRepository({DioClient? dioClient, AppLocalCache? cache})
    : _dioClient = dioClient ?? DioClient(),
      _cache = cache ?? AppLocalCache.instance;

  static const String _cacheKey = 'cached_feature_flags_v1';
  static const String _billingCacheKey = 'cached_appointment_billing_v1';
  static const String _cacheUpdatedAtKey = 'cached_app_config_updated_at_v1';
  static const Duration cacheFreshness = Duration(minutes: 5);

  bool get hasFreshCache {
    final updatedAtMs = _cache.getInt(_cacheUpdatedAtKey);
    if (updatedAtMs == null) return false;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    );
    return age >= Duration.zero && age < cacheFreshness;
  }

  static const Map<String, bool> defaultFeatures = <String, bool>{
    'shop': true,
    'clinic_appointment': true,
    'assessment': true,
    'videos': true,
    'reviews': true,
    'routine': true,
    'reminders': true,
    'reports': true,
  };

  /// Returns cached flags instantly from local storage for 0ms cold-start latency.
  Map<String, bool> getCachedFeatures() {
    try {
      final cachedJson = _cache.getString(_cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) {
          final result = Map<String, bool>.from(defaultFeatures);
          decoded.forEach((key, value) {
            result[key.toString()] = value == true;
          });
          return result;
        }
      }
    } catch (e) {
      debugPrint('Failed to decode cached feature flags: $e');
    }
    return defaultFeatures;
  }

  /// Returns cached billing configuration instantly.
  AppointmentBillingConfig getCachedBillingConfig() {
    try {
      final cachedJson = _cache.getString(_billingCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) {
          return AppointmentBillingConfig.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to decode cached billing config: $e');
    }
    return const AppointmentBillingConfig();
  }

  /// Synchronizes with backend `/api/v1/app/config` and updates local cache.
  Future<AppConfigBundle> fetchAppConfig() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final response = await _dioClient.dio.get<Map<String, dynamic>>(
        ApiEndpoints.appConfig,
        queryParameters: {
          'platform': platform,
          'version': packageInfo.version,
          'build': packageInfo.buildNumber,
        },
      );
      final body = response.data;
      if (body != null && body['data'] != null) {
        final featuresData = body['data']['features'];
        final billingData = body['data']['appointment_billing'];
        final versionData = body['data']['versionCheck'];

        final featuresResult = Map<String, bool>.from(defaultFeatures);
        if (featuresData is Map) {
          featuresData.forEach((key, value) {
            featuresResult[key.toString()] = value == true;
          });
          await _cache.put(_cacheKey, jsonEncode(featuresResult));
        }

        AppointmentBillingConfig billingResult =
            const AppointmentBillingConfig();
        if (billingData is Map) {
          billingResult = AppointmentBillingConfig.fromJson(
            Map<String, dynamic>.from(billingData),
          );
          await _cache.put(
            _billingCacheKey,
            jsonEncode(billingResult.toJson()),
          );
        }

        // Persist freshness with the same Hive store as the cached payload so
        // a process restart does not immediately refetch unchanged config.
        await _cache.put(
          _cacheUpdatedAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );

        return AppConfigBundle(
          features: featuresResult,
          appointmentBilling: billingResult,
          versionCheck: AppVersionCheck.fromJson(
            versionData is Map ? Map<String, dynamic>.from(versionData) : null,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to fetch app config: $e');
    }
    return AppConfigBundle(
      features: getCachedFeatures(),
      appointmentBilling: getCachedBillingConfig(),
      versionCheck: const AppVersionCheck(),
    );
  }

  Future<Map<String, bool>> fetchAppFeatures() async {
    final bundle = await fetchAppConfig();
    return bundle.features;
  }
}
