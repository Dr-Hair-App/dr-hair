import 'package:dr_hair/core/session/session_coordinator.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/appointments/presentation/clinic_appointment_cubit.dart';
import 'package:dr_hair/features/auth/domain/models/user_model.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_cubit.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/home/presentation/viewmodels/home_summary_cubit.dart';
import 'package:dr_hair/features/treatment/data/patient_clinical_api.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/cart_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingClinicalApi extends Fake implements PatientClinicalApi {
  int homeSummaryRequests = 0;

  @override
  Future<Map<String, dynamic>> getHomeSummary(String accessToken) async {
    homeSummaryRequests += 1;
    return {
      'patient_status': const <String, dynamic>{},
      'feature_flags': const <String, dynamic>{},
      'action_cards': const <dynamic>[],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a report push refreshes home once per report and ignores non-report pushes', () async {
    await AppLocalCache.instance.clearAll();
    final authCubit = AuthCubit();
    final careCubit = CareCubit();
    final cartCubit = CartCubit();
    final appointmentCubit = ClinicAppointmentCubit();
    final hairTestCubit = HairTestCubit();
    final api = _CountingClinicalApi();
    final homeCubit = HomeSummaryCubit(clinicalApi: api);
    final coordinator = SessionCoordinator.instance;

    coordinator.attach(
      authCubit: authCubit,
      careCubit: careCubit,
      cartCubit: cartCubit,
      appointmentCubit: appointmentCubit,
      hairTestCubit: hairTestCubit,
      homeSummaryCubit: homeCubit,
    );
    authCubit.emitForTesting(
      const AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(
          id: '42',
          emailOrPhone: '9876543210',
          name: 'Test Patient',
          phone: '9876543210',
          email: 'patient@example.com',
        ),
        sessionToken: 'test-token',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.homeSummaryRequests, 1);

    coordinator.refreshHomeSummaryForReportNotification({
      'destination_type': 'report',
      'report_id': 'report-123',
      'notification_id': 'notification-1',
    });
    await Future<void>.delayed(Duration.zero);
    expect(api.homeSummaryRequests, 2);

    coordinator.refreshHomeSummaryForReportNotification({
      'destination_type': 'report',
      'report_id': 'report-123',
      'notification_id': 'notification-2',
    });
    coordinator.refreshHomeSummaryForReportNotification({
      'destination_type': 'report',
      'report_id': 'report-123',
      'notification_id': 'notification-2',
    });
    coordinator.refreshHomeSummaryForReportNotification({
      'type': 'order',
      'entity_id': 'order-123',
    });
    await Future<void>.delayed(Duration.zero);
    expect(api.homeSummaryRequests, 3);

    coordinator.dispose();
    await authCubit.close();
    await careCubit.close();
    await cartCubit.close();
    await appointmentCubit.close();
    await hairTestCubit.close();
    await homeCubit.close();
  });
}
