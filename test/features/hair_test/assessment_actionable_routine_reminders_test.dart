import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dr_hair/features/care/presentation/viewmodels/care_cubit.dart';
import 'package:dr_hair/features/hair_test/domain/models/ai_assessment_model.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_state.dart';
import 'package:dr_hair/features/hair_test/presentation/widgets/assessment_actionable_suggestions.dart';
import 'package:dr_hair/features/hair_test/presentation/widgets/assessment_product_usage_reminders.dart';
import 'package:dr_hair/features/hair_test/presentation/widgets/assessment_reminder_dialog.dart';
import 'package:dr_hair/features/shop/data/models/product_model.dart';

Widget _wrapWithProviders(
  Widget child, {
  CareCubit? careCubit,
  HairTestCubit? hairTestCubit,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<CareCubit>.value(value: careCubit ?? CareCubit()),
      BlocProvider<HairTestCubit>.value(value: hairTestCubit ?? HairTestCubit()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssessmentActionableSuggestionsCard Widget Tests', () {
    testWidgets('renders critical consultation guidance when scalp health score < 50', (tester) async {
      const criticalAssessment = AiAssessmentModel(
        scalpHealthScore: 42,
        stageClassification: 'Stage 4 - Advanced Thinning',
        summary: 'Significant hair loss requiring urgent clinical attention.',
        isCritical: true,
        rootCauses: [
          AiRootCause(
            factor: 'DHT Sensitivity',
            severity: 'Severe',
            explanation: 'High androgen sensitivity.',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          const AssessmentActionableSuggestionsCard(
            state: HairTestState(primaryConcern: 'dandruff and thinning'),
            aiAssessment: criticalAssessment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Actionable Suggestions & AI Plan'), findsOneWidget);
      expect(find.text('Clinical Trichology Consultation (High Urgency)'), findsOneWidget);
      expect(find.text('Book In-Clinic Slot'), findsOneWidget);
      expect(find.text('Daily Routine Modifications'), findsOneWidget);
      expect(find.text('Dietary & Nutritional Modifications'), findsOneWidget);
      expect(find.text('Auto List / Add to My Routine'), findsOneWidget);
    });

    testWidgets('renders WhatsApp doctor consultation for non-critical cases', (tester) async {
      const nonCriticalAssessment = AiAssessmentModel(
        scalpHealthScore: 74,
        stageClassification: 'Stage 2 - Early Thinning',
        summary: 'Mild thinning manageable with routine and targeted diet.',
        isCritical: false,
        rootCauses: [
          AiRootCause(
            factor: 'Stress & Cortisol',
            severity: 'Moderate',
            explanation: 'Elevated stress triggers telogen phase.',
          ),
        ],
        dietPlan: AiDietPlan(
          foodsToEat: ['Eggs', 'Paneer', 'Pumpkin seeds'],
          hydrationTarget: '2.5L daily',
        ),
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          const AssessmentActionableSuggestionsCard(
            state: HairTestState(primaryConcern: 'hair shedding'),
            aiAssessment: nonCriticalAssessment,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Doctor Guidance & Clinical Review'), findsOneWidget);
      expect(find.text('Connect on WhatsApp'), findsOneWidget);
      expect(find.text('Clinic Visit'), findsOneWidget);
      expect(find.text('Wash Cadence & Cleansing'), findsOneWidget);
      expect(find.text('Dermal Papilla Massage'), findsOneWidget);
    });

    testWidgets('tapping "Auto List / Add to My Routine" persists tasks and meals to CareCubit', (tester) async {
      final careCubit = CareCubit();

      const assessment = AiAssessmentModel(
        scalpHealthScore: 68,
        stageClassification: 'Stage 2 - Mild Thinning',
        summary: 'Mild hairline thinning and dry scalp.',
        recommendedRegimen: AiRecommendedRegimen(
          dailySteps: [
            AiRegimenStep(
              step: 'Morning Scalp Tonic',
              instruction: 'Apply 1ml tonic to hairline after showering.',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          const AssessmentActionableSuggestionsCard(
            state: HairTestState(primaryConcern: 'dry scalp'),
            aiAssessment: assessment,
          ),
          careCubit: careCubit,
        ),
      );
      await tester.pumpAndSettle();

      final autoListButton = find.text('Auto List / Add to My Routine');
      expect(autoListButton, findsOneWidget);

      await tester.ensureVisible(autoListButton);
      await tester.pumpAndSettle();
      await tester.tap(autoListButton);
      await tester.pumpAndSettle();

      expect(find.text('Added to Today\'s Routine & Diet Plan!'), findsOneWidget);
      expect(find.text('Open Routine'), findsOneWidget);
      expect(find.text('Open Diet Plan'), findsOneWidget);

      // Verify that tasks were saved into CareCubit state
      expect(careCubit.state.routineTasks.isNotEmpty, isTrue);
      expect(
        careCubit.state.routineTasks.any((t) => t.title.contains('Scalp')),
        isTrue,
      );
      // Verify that assistant diet meals were saved into CareCubit state
      expect(careCubit.state.assistantDietMeals.isNotEmpty, isTrue);
    });
  });

  group('AssessmentProductUsageRemindersCard Widget Tests', () {
    testWidgets('displays dosage, timing, and application instructions', (tester) async {
      const sampleProduct = ProductItem(
        id: 'prod_serum_1',
        name: 'Dr. Hair Follicle Activator Serum',
        subtitle: 'Advanced Growth Formula',
        category: 'Topical Solution',
        rootCause: 'DHT Sensitivity',
        rating: 4.8,
        reviewsCount: 120,
        inStock: true,
        images: ['https://example.com/serum.jpg'],
        supplyPlans: [],
        benefits: [],
        ingredients: [],
        usageSteps: [
          ProductUsageStep(
            step: 1,
            title: 'Section Scalp',
            description: 'Part hair into 4 quadrants.',
          ),
          ProductUsageStep(
            step: 2,
            title: 'Apply Dropper',
            description: 'Apply 1ml directly to scalp.',
          ),
        ],
        clinicalMetrics: [],
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          const AssessmentProductUsageRemindersCard(
            aiAssessment: AiAssessmentModel(scalpHealthScore: 70),
            recommendedProducts: [sampleProduct],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Product Usage & Reminders'), findsOneWidget);
      expect(find.text('Dr. Hair Follicle Activator Serum'), findsOneWidget);
      expect(find.text('1ml dropper'), findsOneWidget);
      expect(find.text('Night · 30 min before bed'), findsOneWidget);
      expect(find.text('Part hair into 4 quadrants.'), findsOneWidget);
      expect(find.text('Set Daily Reminder'), findsOneWidget);
    });

    testWidgets('shows active reminder status when reminder exists in CareCubit', (tester) async {
      final careCubit = CareCubit();
      const sampleProduct = ProductItem(
        id: 'prod_serum_1',
        name: 'Dr. Hair Follicle Activator Serum',
        subtitle: 'Serum',
        category: 'Topical Solution',
        rating: 4.8,
        reviewsCount: 100,
        inStock: true,
        images: [],
        supplyPlans: [],
        benefits: [],
        ingredients: [],
        usageSteps: [],
        clinicalMetrics: [],
      );

      // Pre-add an existing reminder to CareCubit
      await careCubit.addReminder(
        title: 'Dr. Hair Follicle Activator Serum',
        subtitle: 'Topical Serum · Daily',
        time: const TimeOfDay(hour: 21, minute: 30),
        frequency: 'Daily',
      );

      await tester.pumpWidget(
        _wrapWithProviders(
          const AssessmentProductUsageRemindersCard(
            aiAssessment: AiAssessmentModel(scalpHealthScore: 70),
            recommendedProducts: [sampleProduct],
          ),
          careCubit: careCubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('9:30 PM'), findsOneWidget);
      expect(find.textContaining('Modify Reminder'), findsOneWidget);
    });
  });

  group('AssessmentReminderDialog Widget Tests', () {
    testWidgets('allows customizing frequency and saving reminder into CareCubit', (tester) async {
      final careCubit = CareCubit();

      await tester.pumpWidget(
        _wrapWithProviders(
          const AssessmentReminderDialog(
            productName: 'Dr. Hair Biotin Gummies',
            treatmentType: 'Oral Supplement',
            defaultDosage: '2 gummies daily',
            defaultTiming: 'Morning with breakfast',
            initialTime: TimeOfDay(hour: 8, minute: 30),
          ),
          careCubit: careCubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set Product Reminder'), findsOneWidget);
      expect(find.text('Dr. Hair Biotin Gummies'), findsOneWidget);
      expect(find.text('8:30 AM'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekdays'), findsOneWidget);
      expect(find.text('Weekends'), findsOneWidget);

      // Tap Weekdays frequency
      await tester.tap(find.text('Weekdays'));
      await tester.pumpAndSettle();

      // Tap Set Reminder button
      final saveButton = find.text('Set Reminder');
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Check that reminder was created in CareCubit
      expect(careCubit.state.reminders.isNotEmpty, isTrue);
      final rem = careCubit.state.reminders.firstWhere(
        (r) => r.title == 'Dr. Hair Biotin Gummies',
      );
      expect(rem.title, 'Dr. Hair Biotin Gummies');
      expect(rem.frequency, 'Weekdays');
      expect(rem.repeatDays, equals([1, 2, 3, 4, 5]));
    });
  });
}
