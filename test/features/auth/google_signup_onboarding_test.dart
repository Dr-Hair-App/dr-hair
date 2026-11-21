import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dr_hair/core/routes/app_router.dart';
import 'package:dr_hair/core/routes/route_names.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_cubit.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:dr_hair/features/auth/presentation/views/signin_view.dart';

import 'fake_auth_repository.dart';

void main() {
  testWidgets('protects direct patient routes and preserves their deep link', (
    tester,
  ) async {
    final authCubit = AuthCubit(repository: FakeAuthRepository());
    authCubit.emit(const AuthState(status: AuthStatus.unauthenticated));
    const requestedLocation = '/products?from=assessment';
    AppRouter.router.go(requestedLocation);

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp.router(routerConfig: AppRouter.router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SigninView), findsOneWidget);
    expect(
      AppRouter.router.routeInformationProvider.value.uri.path,
      RouteNames.signin,
    );
    expect(
      AppRouter
          .router
          .routeInformationProvider
          .value
          .uri
          .queryParameters['redirect'],
      requestedLocation,
    );

    AppRouter.router.go('/hair-test/assessment/HT-PRIVATE');
    await tester.pumpAndSettle();
    expect(find.byType(SigninView), findsOneWidget);
    expect(find.text('Hair & Scalp Assessment'), findsNothing);
  });

  test(
    'keeps Google name and provider through the required mobile OTP',
    () async {
      final cubit = AuthCubit(repository: FakeAuthRepository());
      cubit.emit(
        const AuthState(
          status: AuthStatus.unauthenticated,
          requiresPhoneVerification: true,
          tempToken: 'temporary-social-session',
          socialProvider: 'google',
          socialEmail: 'patient@example.com',
          socialName: 'Google Patient',
        ),
      );

      final verified = await cubit.verifySocialSignup(
        phone: '9876543210',
        otp: '123456',
      );

      expect(verified, isTrue);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.state.nextStep, 'ASSESSMENT');
      expect(cubit.state.socialProvider, 'google');
      expect(cubit.state.socialName, 'Google Patient');
      expect(cubit.state.socialEmail, 'patient@example.com');
      await cubit.close();
    },
  );
}
