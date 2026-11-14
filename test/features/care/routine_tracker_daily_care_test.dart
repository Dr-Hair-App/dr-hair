import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';
import 'package:dr_hair/features/care/presentation/views/routine_tracker_view.dart';

void main() {
  late CareCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocalCache.instance.clearAll();
    cubit = CareCubit();
    cubit.loadSampleFixturesForTesting();
  });

  tearDown(() async => cubit.close());

  Future<void> pumpRoutine(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CareCubit>.value(
          value: cubit,
          child: const RoutineTrackerView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('patient can skip a routine step with an optional reason', (
    tester,
  ) async {
    await pumpRoutine(tester);
    await tester.tap(find.byTooltip('Care step options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for today'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Travelling today');
    await tester.tap(find.text('Skip today'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Skipped today · Travelling today'),
      findsOneWidget,
    );
  });

  testWidgets('symptom check-in with pain recommends clinic contact', (
    tester,
  ) async {
    await pumpRoutine(tester);
    await tester.ensureVisible(find.text('Report a symptom'));
    await tester.tap(find.text('Report a symptom'));
    await tester.pumpAndSettle();
    final painTile = find.widgetWithText(CheckboxListTile, 'Pain');
    await tester.tap(painTile);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(painTile).value, isTrue);
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(find.text('Please contact the clinic'), findsOneWidget);
    expect(cubit.state.careEvents.last.clinicianContactRecommended, isTrue);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}
