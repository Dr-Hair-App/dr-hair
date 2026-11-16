import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_local_cache.dart';
import '../../../treatment/data/patient_clinical_api.dart';
import '../../domain/models/home_action_card.dart';
import 'home_summary_state.dart';

class HomeSummaryCubit extends Cubit<HomeSummaryState> {
  static const _homeSummaryCacheKey = 'cache_home_summary_v1';
  final PatientClinicalApi _clinicalApi;
  String? _sessionToken;

  HomeSummaryCubit({PatientClinicalApi? clinicalApi})
    : _clinicalApi = clinicalApi ?? PatientClinicalApi(),
      super(const HomeSummaryState());

  String? get sessionToken => _sessionToken;

  Future<void> loadHomeSummary([String? token]) async {
    final activeToken = token ?? _sessionToken;
    _sessionToken = activeToken;

    if (activeToken == null || activeToken.trim().isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          isGuest: true,
          data: const HomeSummaryData(),
          clearErrorMessage: true,
        ),
      );
      return;
    }

    // 1. Instant zero-wait cache emission via Hive
    final cached = AppLocalCache.instance.getJson(_homeSummaryCacheKey);
    if (cached != null && cached is Map<String, dynamic>) {
      try {
        final cachedSummary = HomeSummaryData.fromJson(cached);
        emit(
          state.copyWith(
            isLoading: false,
            data: cachedSummary,
            isGuest: false,
            clearErrorMessage: true,
          ),
        );
      } catch (_) {}
    } else {
      emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    }

    // 2. Silent background revalidation
    try {
      final raw = await _clinicalApi.getHomeSummary(activeToken);
      final summary = HomeSummaryData.fromJson(raw);
      await AppLocalCache.instance.putJson(_homeSummaryCacheKey, raw);
      if (!isClosed) {
        emit(
          state.copyWith(
            isLoading: false,
            data: summary,
            isGuest: false,
            clearErrorMessage: true,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        // Keep any cached summary visible, but surface that refresh failed so
        // the UI can offer a retry instead of presenting stale data as live.
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Unable to refresh clinical summary.',
          ),
        );
      }
    }
  }

  Future<Uri?> getReportDownloadUri(String reportId) async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) return null;

    emit(state.copyWith(openingReportId: reportId));
    try {
      final uri = await _clinicalApi.getReportDownloadUri(
        accessToken: token,
        reportId: reportId,
      );
      return uri;
    } catch (_) {
      return null;
    } finally {
      if (!isClosed) {
        emit(state.copyWith(clearOpeningReportId: true));
      }
    }
  }

  Future<void> refresh() async {
    await loadHomeSummary(_sessionToken);
  }

  void bindPatient(String patientId, {String? sessionToken}) {
    _sessionToken = sessionToken;
    loadHomeSummary(sessionToken);
  }

  void clearPatient() {
    _sessionToken = null;
    AppLocalCache.instance.remove(_homeSummaryCacheKey);
    emit(const HomeSummaryState(isGuest: true, data: HomeSummaryData()));
  }
}
