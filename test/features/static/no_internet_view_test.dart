import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/core/services/network_connection_service.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_cubit.dart';
import 'package:dr_hair/features/auth/presentation/viewmodels/auth_state.dart';
import 'package:dr_hair/features/static/presentation/views/no_internet_view.dart';

class _FakeConnectivity implements Connectivity {
  List<ConnectivityResult> results;
  _FakeConnectivity(this.results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value(results);
}

class _TestAuthCubit extends AuthCubit {
  _TestAuthCubit() : super() {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  @override
  Future<void> restoreSession() async {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}

void main() {
  testWidgets('NoInternetView renders title, checklist and triggers retry', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeConnectivity = _FakeConnectivity([ConnectivityResult.none]);
    final networkService = NetworkConnectionService(
      connectivity: fakeConnectivity,
      lookup: (_) async => throw const SocketException('No address associated'),
    );

    final authCubit = _TestAuthCubit();

    await tester.pumpWidget(
      BlocProvider<AuthCubit>.value(
        value: authCubit,
        child: MaterialApp(
          home: NoInternetView(networkService: networkService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify UI Elements
    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.textContaining('We could not reach Dr. Hair clinic servers'), findsOneWidget);
    expect(find.text('Check that Wi-Fi or Mobile Data is turned on'), findsOneWidget);
    expect(find.text('Ensure Airplane mode and VPN are disabled'), findsOneWidget);
    expect(find.text('Retry Connection'), findsOneWidget);
    expect(find.text('Continue to App anyway'), findsOneWidget);

    // Tap Retry while offline
    await tester.tap(find.text('Retry Connection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // SnackBar should appear informing still offline
    expect(find.textContaining('Still offline. Please check your Wi-Fi or mobile data'), findsOneWidget);
  });
}
