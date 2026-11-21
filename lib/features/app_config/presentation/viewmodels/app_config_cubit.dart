import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/app_config_repository.dart';
import 'app_config_state.dart';

/// Cubit managing dynamic feature availability across the app.
class AppConfigCubit extends Cubit<AppConfigState> {
  final AppConfigRepository _repository;
  static const Duration _refreshInterval = Duration(minutes: 5);
  Future<void>? _pendingLoad;
  DateTime? _lastLoadAt;

  AppConfigCubit({AppConfigRepository? repository})
    : _repository = repository ?? AppConfigRepository(),
      super(
        AppConfigState(
          features: (repository ?? AppConfigRepository()).getCachedFeatures(),
          appointmentBilling: (repository ?? AppConfigRepository())
              .getCachedBillingConfig(),
        ),
      ) {
    if (!_repository.hasFreshCache) loadConfig();
  }

  /// Fetches live configuration from the server and updates state/cache.
  /// Loads config once at app startup, coalesces overlapping callers, and
  /// serves the current state for a short freshness window. User initiated
  /// refreshes can bypass the window with [force].
  Future<void> loadConfig({bool force = false}) {
    final pending = _pendingLoad;
    if (pending != null) return pending;

    final lastLoadAt = _lastLoadAt;
    if (!force &&
        lastLoadAt != null &&
        DateTime.now().difference(lastLoadAt) < _refreshInterval) {
      return Future<void>.value();
    }

    _lastLoadAt = DateTime.now();
    final request = _performLoad();
    _pendingLoad = request;
    return request;
  }

  Future<void> _performLoad() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final bundle = await _repository.fetchAppConfig();
      emit(
        state.copyWith(
          features: bundle.features,
          appointmentBilling: bundle.appointmentBilling,
          versionCheck: bundle.versionCheck,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    } finally {
      _pendingLoad = null;
    }
  }

  /// Convenience helper to check if a feature is enabled.
  bool isFeatureEnabled(String key, {bool defaultValue = true}) {
    return state.isFeatureEnabled(key, defaultValue: defaultValue);
  }
}
