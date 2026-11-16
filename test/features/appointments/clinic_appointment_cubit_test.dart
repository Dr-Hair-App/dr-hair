import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/appointments/presentation/clinic_appointment_cubit.dart';
import 'package:dr_hair/features/appointments/data/patient_appointment_api.dart';

class _AppointmentApi extends PatientAppointmentApi {
  var sequence = 0;
  final items = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> create({
    required String token,
    required DateTime startsAt,
    required String reason,
    String paymentMethod = 'Pay at clinic',
  }) async {
    final instant = startsAt.toUtc();
    if (items.any((item) {
      final current = DateTime.tryParse(item['starts_at']?.toString() ?? '');
      return current != null &&
          current.difference(instant).inMinutes.abs() < 30;
    })) {
      throw const FormatException('This clinic slot is already booked.');
    }
    final record = {
      'id': 'test-${++sequence}',
      'patientId': 'PAT-1',
      'starts_at': instant.toIso8601String(),
      'reason': reason,
      'status': 'Requested',
      'opd_token': 'OPD-TEST',
      'consultation_fee': 500,
      'payment_status': 'Pending',
      'payment_method': paymentMethod,
    };
    items.add(record);
    return record;
  }

  @override
  Future<Map<String, dynamic>> update({
    required String token,
    required String appointmentId,
    required Map<String, dynamic> data,
  }) async {
    final index = items.indexWhere((item) => item['id'] == appointmentId);
    final record = {
      if (index >= 0) ...items[index],
      'id': appointmentId,
      ...data,
      'status': data['action'] == 'cancel' ? 'Cancelled' : 'Requested',
    };
    if (index >= 0) items[index] = record;
    return record;
  }

  @override
  Future<List<Map<String, dynamic>>> list(String token) async =>
      List<Map<String, dynamic>>.from(items);
}

void main() {
  test(
    'saves, validates, cancels, and restores a physical visit request',
    () async {
      final cache = AppLocalCache.inMemory();
      final cubit = ClinicAppointmentCubit(
        cache: cache,
        api: _AppointmentApi(),
      );
      final time = DateTime.now().add(const Duration(days: 2));
      expect(
        await cubit.saveRequest(
          patientId: 'PAT-1',
          accessToken: 'test-token',
          startsAt: time,
          reason: 'Scalp scan',
          paymentMethod: 'Pay at clinic',
        ),
        isNull,
      );
      expect(cubit.forPatient('PAT-1'), hasLength(1));
      final apt = cubit.forPatient('PAT-1').first;
      expect(apt.consultationFee, 500);
      expect(apt.paymentStatus, 'Pending');
      expect(apt.paymentMethod, 'Pay at clinic');
      expect(apt.tokenNumber.isNotEmpty, true);
      expect(
        await cubit.saveRequest(
          patientId: 'PAT-1',
          accessToken: 'test-token',
          startsAt: time.add(const Duration(minutes: 10)),
          reason: 'Follow-up visit',
        ),
        isNotNull,
      );
      expect(cubit.forPatient('PAT-1'), hasLength(1));
      final id = cubit.forPatient('PAT-1').first.id;
      final restored = ClinicAppointmentCubit(cache: cache, api: cubit.api)
        ..load();
      expect(restored.forPatient('PAT-1').single.id, id);
      await restored.cancel(id, 'PAT-1', accessToken: 'test-token');
      expect(restored.forPatient('PAT-1').single.status, 'Cancelled');
      await restored.clearForPatient('PAT-1');
      expect(restored.forPatient('PAT-1'), isEmpty);
      await cubit.close();
      await restored.close();
    },
  );

  test(
    'reschedules appointment slot with optimistic update and persistence',
    () async {
      final cache = AppLocalCache.inMemory();
      final cubit = ClinicAppointmentCubit(
        cache: cache,
        api: _AppointmentApi(),
      );
      final initialTime = DateTime.now().add(const Duration(days: 3));

      await cubit.saveRequest(
        patientId: 'PAT-1',
        accessToken: 'test-token',
        startsAt: initialTime,
        reason: 'Scalp scan',
      );

      final appointmentId = cubit.forPatient('PAT-1').first.id;
      final newSlot = DateTime.now().add(const Duration(days: 5));

      final result = await cubit.reschedule(
        id: appointmentId,
        patientId: 'PAT-1',
        accessToken: 'test-token',
        newStartsAt: newSlot,
      );

      expect(result, isNull);
      final updated = cubit.forPatient('PAT-1').first;
      expect(updated.startsAt.isAtSameMomentAs(newSlot), isTrue);
      expect(updated.status, 'Requested');

      // Verify persistence
      final restored = ClinicAppointmentCubit(cache: cache, api: cubit.api)
        ..load();
      expect(
        restored.forPatient('PAT-1').first.startsAt.isAtSameMomentAs(newSlot),
        isTrue,
      );
      expect(restored.forPatient('PAT-1').first.status, 'Requested');

      // Verify rejection if slot is in the past or < 1 hr
      final invalidPast = DateTime.now().subtract(const Duration(hours: 2));
      final errorPast = await cubit.reschedule(
        id: appointmentId,
        patientId: 'PAT-1',
        newStartsAt: invalidPast,
      );
      expect(errorPast, isNotNull);

      await cubit.close();
      await restored.close();
    },
  );
}
