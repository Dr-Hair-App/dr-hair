import 'package:flutter_test/flutter_test.dart';

import 'package:dr_hair/core/routes/route_names.dart';
import 'package:dr_hair/features/auth/domain/models/user_model.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:dr_hair/features/auth/presentation/views/splash_view.dart';

void main() {
  test('unauthenticated patients are sent to sign in before profile checks', () {
    final destination = resolveSplashDestination(
      const AuthState(status: AuthStatus.unauthenticated),
      cachedCompleted: false,
      cachedSkipped: false,
    );

    expect(destination, RouteNames.signin);
  });

  test(
    'restored patient without gender is sent to completion before assessment',
    () {
      final destination = resolveSplashDestination(
        AuthState(
          status: AuthStatus.authenticated,
          sessionToken: 'restored-session',
          isRegistered: true,
          nextStep: 'ASSESSMENT',
          hasCompletedAssessment: false,
          user: const UserModel(
            id: 'patient-1',
            name: 'Google Patient',
            emailOrPhone: 'patient@example.com',
            patientId: 'DHP0001',
          ),
        ),
        cachedCompleted: false,
        cachedSkipped: false,
      );

      final uri = Uri.parse(destination);
      expect(uri.path, RouteNames.completeProfile);
      expect(uri.queryParameters['requireGender'], 'true');
      expect(uri.queryParameters['redirect'], RouteNames.hairTest);
    },
  );

  test('completed patient is not prompted for missing gender again', () {
    final destination = resolveSplashDestination(
      AuthState(
        status: AuthStatus.authenticated,
        sessionToken: 'restored-session',
        isRegistered: true,
        nextStep: 'HOME',
        hasCompletedAssessment: true,
        user: const UserModel(
          id: 'patient-2',
          name: 'Completed Patient',
          emailOrPhone: 'patient@example.com',
          patientId: 'DHP0002',
        ),
      ),
      cachedCompleted: false,
      cachedSkipped: false,
    );

    expect(destination, RouteNames.mainShell);
  });
}
