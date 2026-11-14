import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../treatment/data/patient_clinical_api.dart';
import '../../domain/models/home_action_card.dart';
import 'home_summary_state.dart';

class HomeSummaryCubit extends Cubit<HomeSummaryState> {
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
      emit(state.copyWith(
        isLoading: false,
        isGuest: true,
        data: const HomeSummaryData(),
        clearErrorMessage: true,
      ));
      return;
    }

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));
    try {
      final raw = await _clinicalApi.getHomeSummary(activeToken);
      final summary = HomeSummaryData.fromJson(raw);
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          data: summary,
          isGuest: false,
          clearErrorMessage: true,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        // Fall back gracefully without showing stale or fabricated recommendations
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to load clinical summary.',
        ));
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
    emit(const HomeSummaryState(isGuest: true, data: HomeSummaryData()));
  }
}
