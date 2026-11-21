import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/app_local_cache.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/patient_appointment_api.dart';
import '../domain/clinic_appointment.dart';

class ClinicAppointmentCubit extends Cubit<List<ClinicAppointment>> {
  static const storageKey = 'clinic_appointment_requests_v1';
  final AppLocalCache cache;
  final PatientAppointmentApi api;
  bool isLoading = false;
  String? loadError;

  ClinicAppointmentCubit({AppLocalCache? cache, PatientAppointmentApi? api})
    : cache = cache ?? AppLocalCache.instance,
      api = api ?? PatientAppointmentApi(),
      super(const []);

  void load() {
    final raw = cache.getString(storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      emit(
        decoded
            .map(ClinicAppointment.fromJson)
            .whereType<ClinicAppointment>()
            .toList(),
      );
    } catch (_) {
      // A damaged local preview must not prevent the app from opening.
    }
  }

  DateTime? _lastApiLoadAt;
  Future<void>? _pendingApiLoad;
  static const Duration _appointmentFreshness = Duration(minutes: 2);

  Future<void> loadFromApi([String? token, bool force = false]) {
    final pending = _pendingApiLoad;
    if (pending != null) return pending;

    final last = _lastApiLoadAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _appointmentFreshness &&
        state.isNotEmpty) {
      return Future<void>.value();
    }
    _lastApiLoadAt = DateTime.now();
    final request = _performLoad(token);
    _pendingApiLoad = request;
    return request;
  }

  Future<void> _performLoad(String? token) async {
    final activeToken = token ?? await SecureSessionStore().readToken();
    if (activeToken == null || activeToken.trim().isEmpty) return;
    isLoading = true;
    loadError = null;
    try {
      final records = await api.list(activeToken);
      emit(
        records
            .map(ClinicAppointment.fromJson)
            .whereType<ClinicAppointment>()
            .toList(),
      );
      await _persist();
    } catch (error) {
      loadError = error.toString();
    } finally {
      isLoading = false;
      _pendingApiLoad = null;
      emit(List<ClinicAppointment>.from(state));
    }
  }

  List<ClinicAppointment> forPatient(String patientId, {String? userId}) {
    final cleanPatientId = patientId.trim();
    final cleanUserId = (userId ?? '').trim();
    return state.where((item) {
      if (item.patientId == cleanPatientId) return true;
      if (cleanUserId.isNotEmpty &&
          (item.patientId == cleanUserId ||
              item.patientId.contains(cleanUserId))) {
        return true;
      }
      if (cleanPatientId.isNotEmpty &&
          cleanPatientId != 'GUEST' &&
          item.patientId.contains(cleanPatientId)) {
        return true;
      }
      return false;
    }).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  Future<String?> verifyAndBookPaidAppointment({
    required String patientId,
    required String accessToken,
    required DateTime startsAt,
    required String reason,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    if (patientId.isEmpty || patientId == 'GUEST') {
      return 'Sign in to confirm an appointment.';
    }
    try {
      final res = await api.verifyAndBook(
        token: accessToken,
        startsAt: startsAt,
        reason: reason.trim(),
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );
      final aptData = res['appointment'];
      if (aptData is Map<String, dynamic>) {
        final createdApt = ClinicAppointment.fromJson(aptData);
        if (createdApt != null) {
          emit([createdApt, ...state.where((i) => i.id != createdApt.id)]);
          await _persist();
        }
      }
      await loadFromApi(accessToken, true);
      return null;
    } catch (error) {
      return _errorMessage(error, 'Payment verification or booking failed.');
    }
  }

  Future<String?> saveRequest({
    required String patientId,
    String? accessToken,
    required DateTime startsAt,
    required String reason,
    String? replacingId,
    int? consultationFee,
    String paymentMethod = 'Pay at clinic',
    String paymentStatus = 'Pending',
    String? paymentTransactionId,
  }) async {
    if (patientId.isEmpty || patientId == 'GUEST') {
      return 'Sign in to save an appointment request.';
    }
    if (startsAt.isBefore(DateTime.now())) {
      return 'Choose a future clinic slot.';
    }
    if (reason.trim().isEmpty) return 'Choose a reason for your visit.';
    if (replacingId != null &&
        !state.any(
          (item) =>
              item.id == replacingId &&
              item.patientId == patientId &&
              item.status != 'Cancelled',
        )) {
      return 'This appointment request is no longer available.';
    }
    final activeToken = accessToken ?? await SecureSessionStore().readToken();
    if (activeToken == null || activeToken.isEmpty) {
      return 'Your session has expired. Sign in again to book this appointment.';
    }
    try {
      if (replacingId == null) {
        final res = await api.create(
          token: activeToken,
          startsAt: startsAt,
          reason: reason.trim(),
          paymentMethod: paymentMethod,
        );
        final createdApt = ClinicAppointment.fromJson(res);
        if (createdApt != null) {
          emit([createdApt, ...state.where((i) => i.id != createdApt.id)]);
          await _persist();
        }
      } else {
        await api.update(
          token: activeToken,
          appointmentId: replacingId,
          data: {
            'action': 'reschedule',
            'starts_at': startsAt.toUtc().toIso8601String(),
          },
        );
      }
      await loadFromApi(activeToken, true);
      return null;
    } catch (error) {
      return _errorMessage(error, 'Appointment request could not be saved.');
    }
  }

  Future<String?> reschedule({
    required String id,
    required String patientId,
    required DateTime newStartsAt,
    String? accessToken,
  }) async {
    if (patientId.isEmpty || patientId == 'GUEST') {
      return 'Sign in to reschedule your appointment.';
    }
    final activeToken = accessToken ?? await SecureSessionStore().readToken();
    if (activeToken == null || activeToken.isEmpty) {
      return 'Your session has expired. Sign in again to reschedule.';
    }
    if (newStartsAt.isBefore(DateTime.now())) {
      return 'Choose a future clinic slot.';
    }

    // Direct optimistic update so screen updates immediately
    emit(
      state
          .map(
            (item) => item.id == id
                ? item.copyWith(startsAt: newStartsAt, status: 'Requested')
                : item,
          )
          .toList(),
    );
    await _persist();

    try {
      final res = await api.update(
        token: activeToken,
        appointmentId: id,
        data: {
          'action': 'reschedule',
          'starts_at': newStartsAt.toUtc().toIso8601String(),
        },
      );
      final updatedApt = ClinicAppointment.fromJson(res);
      if (updatedApt != null) {
        emit(state.map((item) => item.id == id ? updatedApt : item).toList());
        await _persist();
      }
      await loadFromApi(activeToken, true);
      return null;
    } catch (error) {
      await loadFromApi(activeToken, true);
      return _errorMessage(error, 'Appointment could not be rescheduled.');
    }
  }

  Future<String?> cancel(
    String id,
    String patientId, {
    String? accessToken,
  }) async {
    final activeToken = accessToken ?? await SecureSessionStore().readToken();
    if (activeToken == null || activeToken.isEmpty) {
      return 'Your session has expired. Sign in again to cancel this appointment.';
    }
    try {
      await api.update(
        token: activeToken,
        appointmentId: id,
        data: {'action': 'cancel'},
      );
      await loadFromApi(activeToken, true);
      return null;
    } catch (error) {
      return _errorMessage(
        error,
        'Appointment request could not be cancelled.',
      );
    }
  }

  Future<void> clearForPatient(String patientId) async {
    emit(state.where((item) => item.patientId != patientId).toList());
    await _persist();
  }

  Future<void> _persist() => cache.put(
    storageKey,
    jsonEncode(state.map((item) => item.toJson()).toList()),
  );

  String _errorMessage(Object error, String fallback) {
    if (error is DioException) {
      final message = error.response?.data;
      if (message is Map && message['message'] is String) {
        return message['message'] as String;
      }
      return error.message ?? fallback;
    }
    return error is FormatException ? error.message : fallback;
  }
}
