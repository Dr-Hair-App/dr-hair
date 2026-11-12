import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../notifications/firebase_push_service.dart';

/// Production crash reporting and non-fatal diagnostic tracking using Firebase Crashlytics.
class CrashlyticsService {
  CrashlyticsService._();

  static bool _initialized = false;

  /// Initializes Crashlytics hooks for framework and platform-level errors.
  static Future<void> initialize() async {
    if (FirebasePushService.isTesting || _initialized) return;

    try {
      // In web or mock environments, Crashlytics may not be supported
      if (kIsWeb) return;

      final crashlytics = FirebaseCrashlytics.instance;

      // Enable collection in release builds; disable in local debug test runs to avoid pollution
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

      // Pass all uncaught errors from the Flutter framework to Crashlytics
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (!kDebugMode) {
          crashlytics.recordFlutterFatalError(details);
        }
        originalOnError?.call(details);
      };

      // Pass all uncaught asynchronous errors not handled by the Flutter framework
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        if (!kDebugMode) {
          crashlytics.recordError(error, stack, fatal: true);
        }
        return true;
      };

      _initialized = true;
      debugPrint('🔔 [Crashlytics] Initialized successfully. Active: ${!kDebugMode}');
    } catch (e) {
      debugPrint('⚠️ [Crashlytics] Initialization error: $e');
    }
  }

  /// Sets an anonymous patient ID for crash attribution without leaking personal data.
  static Future<void> setPatientIdentifier(String patientId) async {
    if (FirebasePushService.isTesting || kIsWeb || !_initialized) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(patientId);
    } catch (_) {}
  }

  /// Clears patient identifier on logout.
  static Future<void> clearPatientIdentifier() async {
    if (FirebasePushService.isTesting || kIsWeb || !_initialized) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (_) {}
  }

  /// Logs a clinical diagnostic breadcrumb before key operations.
  static Future<void> log(String message) async {
    if (FirebasePushService.isTesting || kIsWeb || !_initialized) return;
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  /// Records non-fatal exceptions (e.g. unexpected API parse errors) for triage.
  static Future<void> recordNonFatal(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    if (FirebasePushService.isTesting || kIsWeb || !_initialized) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stack,
        reason: reason,
        fatal: false,
      );
    } catch (_) {}
  }
}
