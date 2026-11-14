import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dr_hair/features/auth/presentation/viewmodels/auth_cubit.dart';
import 'package:dr_hair/features/care/presentation/views/progress_tracking_view.dart';
import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';

void main() {
  testWidgets(
    'progress journal explains that signed-out check-ins stay local',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final authCubit = AuthCubit();
      final careCubit = CareCubit();
      addTearDown(authCubit.close);
      addTearDown(careCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>.value(value: authCubit),
            BlocProvider<CareCubit>.value(value: careCubit),
          ],
          child: const MaterialApp(home: ProgressTrackingView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Signed-out check-ins stay on this device.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Sample timeline entries are demo data'),
        findsNothing,
      );
    },
  );
}
