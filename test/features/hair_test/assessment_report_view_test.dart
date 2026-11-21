import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/hair_test/presentation/views/assessment_report_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/features/hair_test/domain/models/ai_assessment_model.dart';
import 'package:dr_hair/features/shop/data/models/product_model.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/products_cubit.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/products_state.dart';

import '../../helpers/product_test_fixtures.dart';

Widget _reportApp(
  HairTestCubit cubit, {
  List<ProductItem> products = const [],
  bool productsLoading = false,
}) => MultiBlocProvider(
  providers: [
    BlocProvider<HairTestCubit>.value(value: cubit),
    BlocProvider<ProductsCubit>(
      create: (_) => ProductsCubit(
        initialState: ProductsState(
          products: products,
          isLoading: productsLoading,
        ),
      ),
    ),
  ],
  child: MaterialApp(home: AssessmentReportView(state: cubit.state)),
);

void main() {
  group('AssessmentReportView Doctor Review Flow', () {
    testWidgets(
      'renders expert review notice and 3-step timeline when report is submitted',
      (tester) async {
        final cubit = HairTestCubit();
        cubit.emit(
          cubit.state.copyWith(
            isCompleted: true,
            isSubmitted: true,
            assessmentStatus: 'submitted',
            name: 'Rahul Sharma',
            age: '29',
            stage: 'Stage 2 - Receding Hairline',
          ),
        );

        await tester.pumpWidget(_reportApp(cubit));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Status copy stays factual until a clinician review is recorded.
        expect(find.text('Your assessment is ready'), findsOneWidget);
        expect(find.text('Assessment Submitted'), findsOneWidget);
        expect(
          find.textContaining('A clinician review is needed'),
          findsOneWidget,
        );
        expect(find.textContaining('Dr. Jai Bansal'), findsNothing);

        // 3-step timeline
        expect(find.text('Intake Done'), findsOneWidget);
        expect(find.text('AI Review Done'), findsOneWidget);
        expect(find.text('Doctor Review'), findsOneWidget);

        cubit.close();
      },
    );

    testWidgets(
      'does not suggest unverified catalog products before AI is available',
      (tester) async {
        final cubit = HairTestCubit();
        cubit.emit(
          cubit.state.copyWith(
            isCompleted: true,
            isSubmitted: true,
            assessmentStatus: 'submitted',
            name: 'Aarav Gupta',
            age: '26',
            stage: 'Stage 2 - Receding Hairline',
          ),
        );

        await tester.pumpWidget(_reportApp(cubit));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Optional products'), findsNothing);
        expect(find.text('Contact doctor on WhatsApp'), findsOneWidget);

        cubit.close();
      },
    );

    testWidgets(
      'renders hero in-person clinic consultation for Stage 5 severe hair thinning',
      (tester) async {
        final cubit = HairTestCubit();
        cubit.emit(
          cubit.state.copyWith(
            isCompleted: true,
            isSubmitted: true,
            assessmentStatus: 'submitted',
            name: 'Vikram Mehta',
            age: '42',
            stage: 'Stage 5 - Advanced Crown Thinning',
            aiAssessment: const AiAssessmentModel(
              isAvailable: false,
              requiresClinician: true,
              nextStepType: 'doctor_appointment',
              nextStepReason: 'An in-person clinician review is recommended.',
            ),
          ),
        );

        await tester.pumpWidget(_reportApp(cubit));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.text('In-Person Clinical Consultation Recommended'),
          findsOneWidget,
        );
        expect(find.text('Contact doctor on WhatsApp'), findsOneWidget);

        cubit.close();
      },
    );

    testWidgets('renders verified doctor care plan when reviewed by doctor', (
      tester,
    ) async {
      final cubit = HairTestCubit();
      cubit.emit(
        cubit.state.copyWith(
          isCompleted: true,
          isSubmitted: true,
          assessmentStatus: 'reviewed',
          name: 'Neha Verma',
          age: '31',
          stage: 'Stage 1 - Mild Thinning',
          doctorCarePlan: {
            'id': 'plan_001',
            'status': 'active',
            'instructions':
                'Apply 1ml solution nightly. Use shampoo twice weekly.',
            'next_review_date': '2026-12-01',
            'medications': [
              {
                'name': 'Custom Clinical Solution',
                'dosage': '1ml daily at bedtime',
                'instructions': 'Do not wash for 4 hours',
              },
            ],
          },
        ),
      );

      await tester.pumpWidget(_reportApp(cubit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Clinical care plan'), findsOneWidget);
      expect(find.textContaining('Prepared by'), findsNothing);
      expect(
        find.text('Apply 1ml solution nightly. Use shampoo twice weekly.'),
        findsOneWidget,
      );
      expect(find.text('Custom Clinical Solution'), findsOneWidget);

      cubit.close();
    });

    testWidgets(
      'only suggests an AI-matched item when the catalog says in stock',
      (tester) async {
        final cubit = HairTestCubit();
        final liveProduct = ProductTestFixtures.catalog.first;
        final ai = AiAssessmentModel(
          isAvailable: true,
          scalpHealthScore: 74,
          stageClassification: 'Reported pattern',
          summary: 'Screening summary from answers.',
          nextStepType: 'products',
          shopEnabled: true,
          availableProducts: [liveProduct.toJson()],
          recommendedRegimen: AiRecommendedRegimen(
            targetProducts: [
              AiTargetProduct(
                name: 'Serums',
                category: 'Serums',
                reason: 'Optional category suggestion.',
              ),
            ],
          ),
        );
        cubit.emit(
          cubit.state.copyWith(
            isCompleted: true,
            isSubmitted: true,
            assessmentStatus: 'submitted',
            stage: 'Stage 2 - Receding Hairline',
            aiAssessment: ai,
          ),
        );

        await tester.pumpWidget(_reportApp(cubit, products: [liveProduct]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(liveProduct.name), findsWidgets);
        expect(find.text('Open daily care routine'), findsOneWidget);
        expect(find.text('WhatsApp Doctor'), findsOneWidget);
        expect(find.text('Retest'), findsOneWidget);
        await cubit.close();
      },
    );

    testWidgets(
      'care and clinician actions stay available when stock cannot be confirmed',
      (tester) async {
        final cubit = HairTestCubit();
        const ai = AiAssessmentModel(
          isAvailable: true,
          scalpHealthScore: 74,
          stageClassification: 'Reported pattern',
          summary: 'Screening summary from answers.',
          nextStepType: 'products',
          productAvailabilityStatus: 'unavailable',
          shopEnabled: true,
        );
        cubit.emit(
          cubit.state.copyWith(
            isCompleted: true,
            isSubmitted: true,
            assessmentStatus: 'submitted',
            stage: 'Stage 2 - Receding Hairline',
            aiAssessment: ai,
          ),
        );

        await tester.pumpWidget(_reportApp(cubit));
        await tester.pump();

        expect(
          find.textContaining('couldn’t confirm current stock'),
          findsOneWidget,
        );
        expect(find.text('Open daily care routine'), findsOneWidget);
        expect(find.text('WhatsApp Doctor'), findsOneWidget);
        expect(find.text('Retest'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets('hides an out-of-stock suggestion and offers doctor contact', (
      tester,
    ) async {
      final cubit = HairTestCubit();
      final soldOutProduct = ProductItem.fromJson({
        'id': 'sold-out-serum',
        'name': 'Sold Out Serum',
        'category': 'Serums',
        'in_stock': false,
        'price': 1200,
      });
      const ai = AiAssessmentModel(
        isAvailable: true,
        scalpHealthScore: 74,
        stageClassification: 'Reported pattern',
        summary: 'Screening summary from answers.',
        nextStepType: 'products',
        shopEnabled: true,
        recommendedRegimen: AiRecommendedRegimen(
          targetProducts: [
            AiTargetProduct(
              name: 'Serums',
              category: 'Serums',
              reason: 'Optional category suggestion.',
            ),
          ],
        ),
      );
      cubit.emit(
        cubit.state.copyWith(
          isCompleted: true,
          isSubmitted: true,
          assessmentStatus: 'submitted',
          stage: 'Stage 2 - Receding Hairline',
          aiAssessment: ai,
        ),
      );

      await tester.pumpWidget(_reportApp(cubit, products: [soldOutProduct]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sold Out Serum'), findsNothing);
      expect(
        find.textContaining(
          'No matching in-stock products are available right now.',
        ),
        findsOneWidget,
      );
      expect(find.text('WhatsApp Doctor'), findsOneWidget);
      await cubit.close();
    });
  });
}
