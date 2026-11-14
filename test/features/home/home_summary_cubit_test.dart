import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/features/home/presentation/viewmodels/home_summary_cubit.dart';
import 'package:dr_hair/features/treatment/data/patient_clinical_api.dart';

class _FakePatientClinicalApi extends Fake implements PatientClinicalApi {
  final Map<String, dynamic>? mockResponse;
  final Exception? throwError;
  final Uri? downloadUri;

  _FakePatientClinicalApi({
    this.mockResponse,
    this.throwError,
    this.downloadUri,
  });

  @override
  Future<Map<String, dynamic>> getHomeSummary(String accessToken) async {
    if (throwError != null) throw throwError!;
    return mockResponse ?? {
      'patient': {'id': 'pat-1', 'name': 'Test Patient'},
      'action_cards': [
        {
          'id': 'card-1',
          'type': 'clinician_urgent',
          'priority': 100,
          'title': 'Urgent Clinic Evaluation Recommended',
          'body': 'Rapid progressive thinning detected. Please consult a clinician.',
          'action_label': 'Book Clinic Consultation',
          'destination_route': '/clinic-appointment',
          'entity_id': 'asmt-1',
          'why_shown': 'Clinical flag: rapid thinning',
        },
        {
          'id': 'card-2',
          'type': 'shared_report',
          'priority': 80,
          'title': 'New report from clinic',
          'body': 'Your trichoscopy report is ready for review.',
          'action_label': 'Open report',
          'entity_id': 'rep-1',
          'why_shown': 'Clinic shared a diagnostic report',
        },
        {
          'id': 'card-3',
          'type': 'care_plan',
          'priority': 70,
          'title': 'Your care plan',
          'body': 'Active 90-day regrowth protocol.',
          'action_label': 'View plan',
          'entity_id': 'cp-1',
        },
      ],
    };
  }

  @override
  Future<Uri> getReportDownloadUri({
    required String accessToken,
    required String reportId,
  }) async {
    if (throwError != null) throw throwError!;
    return downloadUri ?? Uri.parse('https://example.com/reports/$reportId.pdf');
  }
}

void main() {
  group('HomeSummaryCubit', () {
    test('initial state has empty data and is not loading', () {
      final cubit = HomeSummaryCubit(clinicalApi: _FakePatientClinicalApi());
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.hasCards, isFalse);
      expect(cubit.state.isGuest, isFalse);
      cubit.close();
    });

    test('loadHomeSummary with null or empty token sets guest state', () async {
      final cubit = HomeSummaryCubit(clinicalApi: _FakePatientClinicalApi());
      await cubit.loadHomeSummary(null);

      expect(cubit.state.isGuest, isTrue);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.hasCards, isFalse);

      await cubit.loadHomeSummary('');
      expect(cubit.state.isGuest, isTrue);
      cubit.close();
    });

    test('loadHomeSummary loads and orders action cards by priority', () async {
      final cubit = HomeSummaryCubit(clinicalApi: _FakePatientClinicalApi());
      await cubit.loadHomeSummary('valid-token');

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.isGuest, isFalse);
      expect(cubit.state.hasCards, isTrue);
      expect(cubit.state.actionCards.length, 3);

      final urgentCard = cubit.state.actionCards.first;
      expect(urgentCard.isClinicianUrgent, isTrue);
      expect(urgentCard.title, 'Urgent Clinic Evaluation Recommended');
      expect(urgentCard.whyShown, 'Clinical flag: rapid thinning');

      final reportCard = cubit.state.actionCards[1];
      expect(reportCard.isSharedReport, isTrue);
      expect(reportCard.title, 'New report from clinic');

      final carePlanCard = cubit.state.actionCards[2];
      expect(carePlanCard.isCarePlan, isTrue);
      expect(carePlanCard.title, 'Your care plan');

      cubit.close();
    });

    test('loadHomeSummary handles API failure gracefully without crashing', () async {
      final cubit = HomeSummaryCubit(
        clinicalApi: _FakePatientClinicalApi(
          throwError: Exception('Network offline'),
        ),
      );

      await cubit.loadHomeSummary('token');
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.hasCards, isFalse);
      cubit.close();
    });

    test('getReportDownloadUri returns URI from clinical api', () async {
      final cubit = HomeSummaryCubit(
        clinicalApi: _FakePatientClinicalApi(
          downloadUri: Uri.parse('https://example.com/download.pdf'),
        ),
      );

      await cubit.loadHomeSummary('token');
      final uri = await cubit.getReportDownloadUri('rep-123');

      expect(uri, Uri.parse('https://example.com/download.pdf'));
      expect(cubit.state.openingReportId, isNull);
      cubit.close();
    });

    test('loadHomeSummary parses custom mock response data', () async {
      final cubit = HomeSummaryCubit(
        clinicalApi: _FakePatientClinicalApi(
          mockResponse: {
            'action_cards': [
              {
                'id': 'card-custom',
                'type': 'routine_progress',
                'priority': 40,
                'title': 'Week 4 Regrowth Routine',
                'body': 'Keep up your daily regimen.',
                'action_label': 'View Routine',
              },
            ],
          },
        ),
      );

      await cubit.loadHomeSummary('token');
      expect(cubit.state.actionCards.length, 1);
      expect(cubit.state.actionCards.first.title, 'Week 4 Regrowth Routine');
      cubit.close();
    });

    test('clearPatient resets state to guest', () async {
      final cubit = HomeSummaryCubit(clinicalApi: _FakePatientClinicalApi());
      await cubit.loadHomeSummary('token');
      expect(cubit.state.hasCards, isTrue);

      cubit.clearPatient();
      expect(cubit.state.isGuest, isTrue);
      expect(cubit.state.hasCards, isFalse);
      expect(cubit.sessionToken, isNull);
      cubit.close();
    });
  });
}
