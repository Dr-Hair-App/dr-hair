import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/app_local_cache.dart';
import '../../../treatment/data/patient_clinical_api.dart';
import '../../domain/models/home_action_card.dart';
import 'home_summary_state.dart';

class HomeSummaryCubit extends Cubit<HomeSummaryState> {
  static const _homeSummaryCacheKey = 'cache_home_summary_v1';
  static const _viewedReportsKey = 'viewed_shared_reports_v1';
  final PatientClinicalApi _clinicalApi;
  String? _sessionToken;
  String? _patientId;
  final Set<String> _viewedReportIds = <String>{};

  HomeSummaryCubit({PatientClinicalApi? clinicalApi})
    : _clinicalApi = clinicalApi ?? PatientClinicalApi(),
      super(const HomeSummaryState());

  String? get sessionToken => _sessionToken;
  PatientClinicalApi get clinicalApi => _clinicalApi;

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
    final cacheKey = _patientId == null
        ? null
        : AppLocalCache.patientKey(_patientId!, _homeSummaryCacheKey);
    if (_patientId != null) {
      _loadViewedReportIds();
    }
    final cached = cacheKey == null
        ? null
        : AppLocalCache.instance.getJson(cacheKey);
    if (cached != null && cached is Map<String, dynamic>) {
      try {
        final cachedSummary = _hideViewedReports(
          HomeSummaryData.fromJson(cached),
        );
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
      if (raw['latest_report'] == null) {
        final rawCards = raw['action_cards'];
        final hasSharedReportCard = rawCards is List &&
            rawCards.any((c) => c is Map && c['type'] == 'shared_report');
        final status =
            raw['patient_status'] is Map ? raw['patient_status'] as Map : null;
        final reportCount =
            int.tryParse(status?['shared_reports_count']?.toString() ?? '') ?? 0;
        if (hasSharedReportCard || reportCount > 0) {
          try {
            final record = await _clinicalApi.getClinicalRecord(activeToken);
            final reports = record['reports'];
            if (reports is List && reports.isNotEmpty) {
              final validReports = reports.whereType<Map>().toList();
              validReports.sort((a, b) {
                final dateA = DateTime.tryParse(
                      a['created_at']?.toString() ?? '',
                    ) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final dateB = DateTime.tryParse(
                      b['created_at']?.toString() ?? '',
                    ) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return dateB.compareTo(dateA);
              });
              if (validReports.isNotEmpty) {
                raw['latest_report'] = Map<String, dynamic>.from(
                  validReports.first,
                );
              }
            }
          } catch (_) {}
        }
      }
      final summary = _hideViewedReports(HomeSummaryData.fromJson(raw));
      if (cacheKey != null) {
        await AppLocalCache.instance.putJson(cacheKey, raw);
      }
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

  void _loadViewedReportIds() {
    final patientId = _patientId;
    if (patientId == null) return;
    final cached = AppLocalCache.instance.getJson(
      AppLocalCache.patientKey(patientId, _viewedReportsKey),
    );
    _viewedReportIds
      ..clear()
      ..addAll(cached is List ? cached.whereType<String>() : const <String>[]);
  }

  HomeSummaryData _hideViewedReports(HomeSummaryData data) {
    if (_viewedReportIds.isEmpty) return data;
    return data.copyWith(
      actionCards: data.actionCards
          .where((card) {
            return !card.isSharedReport ||
                card.entityId == null ||
                !_viewedReportIds.contains(card.entityId);
          })
          .toList(growable: false),
    );
  }

  Future<void> markSharedReportViewed(String reportId) async {
    final patientId = _patientId;
    final cleanReportId = reportId.trim();
    if (patientId == null || cleanReportId.isEmpty) return;
    _viewedReportIds.add(cleanReportId);
    await AppLocalCache.instance.putJson(
      AppLocalCache.patientKey(patientId, _viewedReportsKey),
      _viewedReportIds.toList(growable: false),
    );
    final data = state.data;
    if (data != null && !isClosed) {
      emit(state.copyWith(data: _hideViewedReports(data)));
    }
  }

  bool isReportUnread(String? reportId) {
    if (reportId == null || reportId.trim().isEmpty) return false;
    return !_viewedReportIds.contains(reportId.trim());
  }

  Future<void> refresh() async {
    await loadHomeSummary(_sessionToken);
  }

  void bindPatient(String patientId, {String? sessionToken}) {
    _patientId = patientId;
    _sessionToken = sessionToken;
    _loadViewedReportIds();
    loadHomeSummary(sessionToken);
  }

  void clearPatient() {
    final patientId = _patientId;
    if (patientId != null) {
      AppLocalCache.instance.remove(
        AppLocalCache.patientKey(patientId, _homeSummaryCacheKey),
      );
    }
    _patientId = null;
    _viewedReportIds.clear();
    _sessionToken = null;
    AppLocalCache.instance.remove(_homeSummaryCacheKey);
    emit(const HomeSummaryState(isGuest: true, data: HomeSummaryData()));
  }
}
