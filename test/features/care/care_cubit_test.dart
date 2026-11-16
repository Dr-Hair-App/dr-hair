import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/care/data/patient_progress_api.dart';
import 'package:dr_hair/features/care/data/patient_diet_api.dart';
import 'package:dr_hair/features/shop/data/datasources/commerce_remote_data_source.dart';
import 'package:dr_hair/features/care/domain/models/care_models.dart';
import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';
import 'package:dr_hair/features/treatment/data/patient_clinical_api.dart';

void main() {
  group('CareCubit Tests', () {
    late CareCubit cubit;

    setUp(() async {
      await AppLocalCache.instance.clearAll();
      cubit = CareCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test(
      'initial state starts with clean unpopulated patient checkIns and orders',
      () {
        expect(cubit.state.checkIns, isEmpty);
        expect(cubit.state.orders, isEmpty);
        expect(cubit.state.routineTasks, isEmpty);
        expect(cubit.state.reminders, isEmpty);
        expect(cubit.state.dietPlans, isEmpty);
      },
    );

    test('addProgressCheckIn prepends new photo checkin to list', () {
      cubit.addProgressCheckIn(
        date: DateTime.now(),
        imagePath: '/mock/path/scalp.jpg',
        scalpRegion: 'Crown / Vertex',
        sheddingLevel: 'Low / Normal',
        notes: 'Great hair density improvement',
        densityRating: 5,
      );

      expect(cubit.state.checkIns.length, equals(1));
      expect(
        cubit.state.checkIns.first.imagePath,
        equals('/mock/path/scalp.jpg'),
      );
      expect(cubit.state.checkIns.first.densityRating, equals(5));
    });

    test('deleteProgressCheckIn removes checkin by id', () async {
      cubit.addProgressCheckIn(
        date: DateTime.now(),
        imagePath: '/mock/path/scalp.jpg',
        scalpRegion: 'Crown / Vertex',
        sheddingLevel: 'Low / Normal',
        notes: 'Baseline photo',
      );
      final firstId = cubit.state.checkIns.first.id;

      await cubit.deleteProgressCheckIn(firstId);
      expect(cubit.state.checkIns, isEmpty);
    });

    test(
      'failed server delete keeps the patient check-in in local history',
      () async {
        final failingProgressApi = _FakeProgressApi()
          ..deleteError = StateError('server unavailable');
        final backendBoundCubit = CareCubit(
          null,
          null,
          failingProgressApi,
          _FakeCommerceApi(),
          _FakeDietApi(),
        );
        backendBoundCubit.addProgressCheckIn(
          id: 'ci_keep_on_failure',
          date: DateTime.now(),
          imagePath: '/mock/path/progress.jpg',
          scalpRegion: 'Crown',
          sheddingLevel: 'Normal',
          notes: 'Keep if remote deletion fails',
        );

        await expectLater(
          backendBoundCubit.deleteProgressCheckIn(
            'ci_keep_on_failure',
            sessionToken: 'valid_jwt_token',
          ),
          throwsA(isA<StateError>()),
        );
        expect(backendBoundCubit.state.checkIns, hasLength(1));
        expect(
          backendBoundCubit.state.checkIns.single.id,
          'ci_keep_on_failure',
        );
        await backendBoundCubit.close();
      },
    );

    test('patient care data isolation: sign-out clears care data and cannot bleed between users', () async {
      await cubit.bindPatient('patient_101');
      cubit.addProgressCheckIn(
        date: DateTime.now(),
        imagePath: '/mock/path/patient1.jpg',
        scalpRegion: 'Frontal Hairline',
        sheddingLevel: 'Moderate',
        notes: 'Patient 101 private progress notes',
      );
      expect(cubit.state.checkIns.length, equals(1));
      expect(
        cubit.state.checkIns.first.notes,
        equals('Patient 101 private progress notes'),
      );

      // Clear on sign out
      await cubit.clearPersonalCareData();
      expect(cubit.state.checkIns, isEmpty);

      // New patient signs in
      await cubit.bindPatient('patient_202');
      expect(cubit.state.checkIns, isEmpty);
    });

    test(
      'toggleRoutineTask records completion in the daily event state',
      () async {
        cubit.loadSampleFixturesForTesting();
        final task = cubit.state.routineTasks.first;
        final wasCompleted = task.isCompleted;

        await cubit.toggleRoutineTask(task.id);
        final updated = cubit.state.routineTasks.firstWhere(
          (t) => t.id == task.id,
        );
        expect(updated.isCompleted, equals(!wasCompleted));
        expect(
          cubit.state.careEvents.any(
            (event) =>
                event.eventType == 'routine' &&
                event.eventKey == task.id &&
                event.status == 'completed',
          ),
          isTrue,
        );
      },
    );

    test('routine step can be skipped with an optional reason', () async {
      cubit.loadSampleFixturesForTesting();
      final task = cubit.state.routineTasks.first;
      await cubit.skipRoutineTask(task.id, reason: 'Travelling today');
      final skipped = cubit.state.routineTasks.firstWhere(
        (item) => item.id == task.id,
      );
      expect(skipped.isSkipped, isTrue);
      expect(skipped.skipReason, 'Travelling today');
      expect(
        cubit.state.careEvents.any(
          (event) => event.eventKey == task.id && event.status == 'skipped',
        ),
        isTrue,
      );
    });

    test(
      'offline care event is queued locally and synced on next session refresh',
      () async {
        final api = _FakeClinicalApi({})
          ..careEventSaveError = StateError('offline');
        final offlineCubit = CareCubit(
          null,
          api,
          _FakeProgressApi(),
          _FakeCommerceApi(),
          _FakeDietApi(),
        );
        await offlineCubit.bindPatient(
          'patient_sync',
          sessionToken: 'session-token',
        );
        offlineCubit.loadSampleFixturesForTesting();
        final stepId = offlineCubit.state.routineTasks.first.id;
        await offlineCubit.skipRoutineTask(stepId, reason: 'Travel');
        expect(offlineCubit.state.isCareEventSyncPending, isTrue);

        api.careEventSaveError = null;
        await offlineCubit.bindPatient(
          'patient_sync',
          sessionToken: 'session-token',
        );
        expect(offlineCubit.state.isCareEventSyncPending, isFalse);
        expect(
          offlineCubit.state.careEvents.any(
            (event) => event.eventKey == stepId && event.status == 'skipped',
          ),
          isTrue,
        );
        await offlineCubit.close();
      },
    );

    test('addCustomRoutineTask adds custom task', () {
      final initialCount = cubit.state.routineTasks.length;
      cubit.addCustomRoutineTask(
        title: 'Scalp Dermarolling',
        subtitle: '0.5mm weekly needle roller',
        category: 'Clinical Topical',
        timeOfDay: 'Night',
      );

      expect(cubit.state.routineTasks.length, equals(initialCount + 1));
      expect(cubit.state.routineTasks.last.title, equals('Scalp Dermarolling'));
    });

    test('resetTodayRoutine marks all tasks incomplete', () async {
      cubit.loadSampleFixturesForTesting();
      await cubit.resetTodayRoutine();
      expect(cubit.state.routineTasks.every((t) => !t.isCompleted), isTrue);
      expect(cubit.state.completedRoutineCount, equals(0));
    });

    test(
      'toggleReminder and updateReminderTime update reminder state',
      () async {
        cubit.loadSampleFixturesForTesting();
        final reminder = cubit.state.reminders.first;
        final wasEnabled = reminder.isEnabled;

        await cubit.toggleReminder(reminder.id, !wasEnabled);
        expect(
          cubit.state.reminders
              .firstWhere((r) => r.id == reminder.id)
              .isEnabled,
          equals(!wasEnabled),
        );

        const newTime = TimeOfDay(hour: 7, minute: 45);
        await cubit.updateReminderTime(reminder.id, newTime);
        expect(
          cubit.state.reminders.firstWhere((r) => r.id == reminder.id).time,
          equals(newTime),
        );
      },
    );

    test(
      'an empty server reminder list clears stale local reminders',
      () async {
        final api = _FakeClinicalApi({});
        final syncedCubit = CareCubit(
          null,
          api,
          _FakeProgressApi(),
          _FakeCommerceApi(),
          _FakeDietApi(),
        );
        syncedCubit.loadSampleFixturesForTesting();
        expect(syncedCubit.state.reminders, isNotEmpty);

        await syncedCubit.bindPatient(
          'patient_303',
          sessionToken: 'fake-token',
        );

        expect(syncedCubit.state.reminders, isEmpty);
        await syncedCubit.close();
      },
    );

    test(
      'toggleDietMeal and water intake functions update state correctly',
      () async {
        cubit.loadSampleFixturesForTesting();
        cubit.selectDietDay(1);
        expect(cubit.state.currentDietDay, equals(1));

        final wasMealDone = cubit.state.dietPlans[1][0].isCompleted;
        await cubit.toggleDietMeal(1, 0);
        expect(cubit.state.dietPlans[1][0].isCompleted, equals(!wasMealDone));

        final initialWater = cubit.state.waterCups;
        await cubit.incrementWater();
        expect(cubit.state.waterCups, equals(initialWater + 1));

        await cubit.decrementWater();
        expect(cubit.state.waterCups, equals(initialWater));
        expect(
          cubit.state.careEvents.any(
            (event) =>
                event.eventType == 'water' && event.value == initialWater,
          ),
          isTrue,
        );
      },
    );

    test('bindPatient with sessionToken fetches clinician care plan and progress checkins', () async {
      final fakeClinical = _FakeClinicalApi(
        {
          'care_plans': [
            {
              'reference_no': 'HT-2026-9001',
              'routine_steps': [
                {
                  'title': 'Minoxidil 5% Application',
                  'subtitle': 'Apply 1ml at night',
                  'category': 'Clinical Topical',
                  'time_of_day': 'Night',
                },
              ],
              'medications': [],
            },
          ],
          'assessments': [],
          'reports': [],
          'appointments': [],
        },
        careEvents: [
          {
            'id': 'event_routine_today',
            'event_date': _dayKey(DateTime.now()),
            'event_type': 'routine',
            'event_key': 'rt_1',
            'status': 'completed',
          },
          {
            'id': 'event_daily_done',
            'event_date': _dayKey(DateTime.now()),
            'event_type': 'routine',
            'event_key': 'daily_complete',
            'status': 'completed',
          },
          {
            'id': 'event_water_today',
            'event_date': _dayKey(DateTime.now()),
            'event_type': 'water',
            'event_key': 'daily_water',
            'status': 'logged',
            'value': 5,
          },
        ],
      );

      final fakeProgress = _FakeProgressApi(
        checkIns: [
          {
            'id': 'ci_remote_1',
            'date': DateTime.now().toIso8601String(),
            'scalp_region': 'Crown',
            'shedding_level': 'Normal',
            'notes': 'Week 4 clinical checkin',
            'density_rating': 4,
            'photos': [
              {
                'angle': 'front',
                'url': 'https://res.cloudinary.com/demo/image/authenticated/s--signed--/user-101/front.jpg',
              },
            ],
          },
        ],
      );

      final backendBoundCubit = CareCubit(
        null,
        fakeClinical,
        fakeProgress,
        _FakeCommerceApi(),
        _FakeDietApi(),
      );

      await backendBoundCubit.bindPatient(
        'patient_99',
        sessionToken: 'valid_jwt_token',
      );

      expect(backendBoundCubit.state.routineTasks.length, equals(1));
      expect(backendBoundCubit.state.routineTasks.first.isCompleted, isTrue);
      expect(backendBoundCubit.state.waterCups, equals(5));
      expect(
        backendBoundCubit.state.routineCompletionDays,
        contains(_dayKey(DateTime.now())),
      );
      expect(
        backendBoundCubit.state.routineTasks.first.title,
        equals('Minoxidil 5% Application'),
      );
      expect(backendBoundCubit.state.checkIns.length, equals(1));
      expect(backendBoundCubit.state.checkIns.first.id, equals('ci_remote_1'));
      expect(
        backendBoundCubit.state.checkIns.first.imagePath,
        contains('user-101/front.jpg'),
      );

      // Deleting checkin delegates to progress api
      await backendBoundCubit.deleteProgressCheckIn(
        'ci_remote_1',
        sessionToken: 'valid_jwt_token',
      );
      expect(fakeProgress.deletedCheckInId, equals('ci_remote_1'));
      expect(backendBoundCubit.state.checkIns, isEmpty);

      // Unbinding patient clears state
      await backendBoundCubit.bindPatient(null);
      expect(backendBoundCubit.state.routineTasks, isEmpty);
      expect(backendBoundCubit.state.checkIns, isEmpty);

      backendBoundCubit.close();
    });

    test(
      'fetchPatientDietPlan loads meals and treatment details from diet API',
      () async {
        final fakeDiet = _FakeDietApi(
          meals: [
            const DietMeal(
              type: 'Breakfast',
              name: 'Sprouted Moong & Paneer',
              nutrients: 'Protein (22g) · Biotin',
              benefit: 'Supports keratin production',
              isCompleted: false,
            ),
          ],
          treatmentName: 'Targeted Follicular Regrowth Diet',
          doctorName: 'Dr. Jai Bansal',
        );

        final dietCubit = CareCubit(null, null, null, null, fakeDiet);
        await dietCubit.fetchPatientDietPlan('test_jwt_token');

        expect(dietCubit.state.dietPlans.length, equals(1));
        expect(
          dietCubit.state.dietPlans.first.first.name,
          equals('Sprouted Moong & Paneer'),
        );
        expect(
          dietCubit.state.dietTreatmentName,
          equals('Targeted Follicular Regrowth Diet'),
        );
        expect(dietCubit.state.dietDoctorName, equals('Dr. Jai Bansal'));
        expect(dietCubit.state.isLoadingDiet, isFalse);

        dietCubit.close();
      },
    );
  });
}

class _FakeDietApi extends PatientDietApi {
  final List<DietMeal> meals;
  final String treatmentName;
  final String doctorName;

  _FakeDietApi({
    this.meals = const [],
    this.treatmentName = 'Personalized Nutrition Plan',
    this.doctorName = 'Dr. Hair Clinical Team',
  });

  @override
  Future<PatientDietPlanResponse> getPatientDietPlan(String token) async {
    return PatientDietPlanResponse(
      meals: meals,
      treatmentName: treatmentName,
      doctorName: doctorName,
    );
  }
}

class _FakeClinicalApi extends PatientClinicalApi {
  final Map<String, dynamic> record;
  final List<Map<String, dynamic>> careEvents;
  final List<Map<String, dynamic>> savedCareEvents = [];
  Object? careEventSaveError;
  _FakeClinicalApi(this.record, {this.careEvents = const []});

  @override
  Future<Map<String, dynamic>> getClinicalRecord(String accessToken) async {
    return record;
  }

  @override
  Future<List<Map<String, dynamic>>> getRoutineSteps(
    String accessToken,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> getReminders(String accessToken) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> getCareEvents({
    required String accessToken,
    required DateTime from,
    required DateTime to,
  }) async => [...careEvents, ...savedCareEvents];

  @override
  Future<Map<String, dynamic>> saveCareEvent({
    required String accessToken,
    required Map<String, dynamic> event,
  }) async {
    if (careEventSaveError != null) throw careEventSaveError!;
    savedCareEvents.add(event);
    return {'item': event, 'clinician_contact_recommended': false};
  }
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _FakeProgressApi extends PatientProgressApi {
  final List<Map<String, dynamic>> checkIns;
  String? deletedCheckInId;
  Object? deleteError;
  _FakeProgressApi({this.checkIns = const []});

  @override
  Future<List<Map<String, dynamic>>> listCheckIns({
    required String token,
  }) async {
    return checkIns;
  }

  @override
  Future<void> deleteCheckIn({
    required String token,
    required String checkInId,
  }) async {
    if (deleteError != null) throw deleteError!;
    deletedCheckInId = checkInId;
  }
}

class _FakeCommerceApi extends CommerceRemoteDataSource {
  @override
  Future<List<CareOrder>> fetchPatientOrders({
    String? token,
    int page = 1,
    int limit = 20,
    String? status,
  }) async => [];
}
