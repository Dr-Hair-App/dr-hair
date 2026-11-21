import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/care/data/patient_diet_api.dart';
import 'package:dr_hair/features/care/data/patient_progress_api.dart';
import 'package:dr_hair/features/care/domain/models/care_models.dart';
import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';
import 'package:dr_hair/features/shop/data/datasources/commerce_remote_data_source.dart';
import 'package:dr_hair/features/treatment/data/patient_clinical_api.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingClinicalApi extends PatientClinicalApi {
  int clinicalRecordCalls = 0;

  @override
  Future<Map<String, dynamic>> getClinicalRecord(String accessToken) async {
    clinicalRecordCalls++;
    return {
      'care_plans': [],
      'reminders': [],
      'diet_plan': null,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getRoutineSteps(String accessToken) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders(String accessToken) async {
    return [];
  }
}

class _DummyProgressApi extends PatientProgressApi {
  @override
  Future<List<Map<String, dynamic>>> listCheckIns({required String token}) async => [];
}

class _DummyCommerceApi extends CommerceRemoteDataSource {
  @override
  Future<List<CareOrder>> fetchPatientOrders({
    String? token,
    String? status,
    int page = 1,
    int limit = 20,
  }) async => [];
}

class _DummyDietApi extends PatientDietApi {
  @override
  Future<PatientDietPlanResponse> getPatientDietPlan(String token) async =>
      const PatientDietPlanResponse(meals: []);
}

void main() {
  setUp(() async {
    await AppLocalCache.instance.clearAll();
  });

  group('CareCubit Thundering Herd Freshness TTL', () {
    test('skips repeated _syncWithBackend calls within 3-minute TTL', () async {
      final clinicalApi = _CountingClinicalApi();
      final cubit = CareCubit(
        null,
        clinicalApi,
        _DummyProgressApi(),
        _DummyCommerceApi(),
        _DummyDietApi(),
      );

      // Initial bind should sync
      await cubit.bindPatient('patient_1', sessionToken: 'test-token');
      expect(clinicalApi.clinicalRecordCalls, 1);
      expect(cubit.lastSyncAt, isNotNull);

      // Second bind with same patient within 3 minutes should skip sync
      await cubit.bindPatient('patient_1', sessionToken: 'test-token');
      expect(clinicalApi.clinicalRecordCalls, 1); // Not called again!

      // Calling with force: true must bypass freshness TTL
      await cubit.bindPatient('patient_1', sessionToken: 'test-token', force: true);
      expect(clinicalApi.clinicalRecordCalls, 2); // Forced sync executed

      await cubit.close();
    });
  });
}
