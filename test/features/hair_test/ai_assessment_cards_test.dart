import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/features/hair_test/domain/models/ai_assessment_model.dart';
import 'package:dr_hair/features/hair_test/presentation/widgets/ai_assessment_cards.dart';

void main() {
  const sampleAi = AiAssessmentModel(
    scalpHealthScore: 78,
    stageClassification: 'Norwood Stage 2 - Early Thinning',
    summary: 'Clinical analysis indicates early frontal recession with healthy crown density.',
    rootCauses: [
      AiRootCause(
        factor: 'DHT Sensitivity',
        severity: 'Moderate',
        explanation: 'Temple follicles show sensitivity to DHT.',
      ),
      AiRootCause(
        factor: 'Scalp Sebum Imbalance',
        severity: 'High',
        explanation: 'Mild dandruff and sebum clogging pores.',
      ),
    ],
    dietPlan: AiDietPlan(
      summary: 'Focus on protein and zinc-rich foods.',
      foodsToEat: ['Eggs & Paneer', 'Spinach & Greens'],
      foodsToAvoid: ['Refined Sugar', 'Oily Snacks'],
      hydrationTarget: '2.5 Litres daily',
      keyNutrients: ['Biotin', 'Zinc', 'Iron'],
    ),
    lifestyleGuidance: AiLifestyleGuidance(
      summary: 'Gentle scalp care and stress reduction.',
      scalpCareTips: ['Wash 2-3 times a week with mild cleanser'],
      oilingRules: ['No overnight oiling with dandruff'],
      sleepAndStress: ['7-8 hours sleep', 'Deep breathing'],
    ),
    recommendedRegimen: AiRecommendedRegimen(
      summary: 'Daily 3-step hair rejuvenation routine.',
      dailySteps: [
        AiRegimenStep(step: 'Morning', instruction: 'Apply follicle serum'),
        AiRegimenStep(step: 'Afternoon', instruction: 'Take Biotin supplement'),
        AiRegimenStep(step: 'Night', instruction: '2 min scalp massage'),
      ],
      targetProducts: [
        AiTargetProduct(
          name: 'Follicle Activator Serum',
          category: 'Serums',
          reason: 'Direct stimulation of roots',
        ),
      ],
    ),
  );

  testWidgets(
    'AiAssessmentCards renders score, stage, and switches tabs cleanly',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiAssessmentCards(aiAssessment: sampleAi),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Score and Stage
      expect(find.text('78'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('Norwood Stage 2 - Early Thinning'), findsOneWidget);
      expect(find.text('Dr. Hair Assistant'), findsOneWidget);
      expect(find.text('Screening result'), findsOneWidget);
      expect(find.textContaining('Gemini'), findsNothing);

      // Default tab is Root Causes
      expect(find.text('DHT Sensitivity'), findsOneWidget);
      expect(
        find.text('Temple follicles show sensitivity to DHT.'),
        findsOneWidget,
      );
      expect(find.text('Scalp Sebum Imbalance'), findsOneWidget);

      // Switch to Diet Plan tab
      await tester.tap(find.text('Diet Plan'));
      await tester.pumpAndSettle();
      expect(find.text('Foods to Eat (Follicle Nourishers)'), findsOneWidget);
      expect(
        find.text('Foods to Avoid (Inflammation Triggers)'),
        findsOneWidget,
      );
      expect(find.text('Daily Hydration Target'), findsOneWidget);
      expect(find.text('2.5 Litres daily'), findsOneWidget);

      // Switch to Lifestyle tab
      await tester.tap(find.text('Lifestyle'));
      await tester.pumpAndSettle();
      expect(find.text('Scalp Hygiene & Washing'), findsOneWidget);
      expect(find.text('Trichology Oiling Guidelines'), findsOneWidget);
      expect(
        find.text('Restorative Sleep & Cortisol Management'),
        findsOneWidget,
      );

      // Switch to Regimen tab
      await tester.tap(find.text('Regimen'));
      await tester.pumpAndSettle();
      expect(find.text('Daily care starter plan'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Afternoon'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
      expect(find.text('Targeted Regimen Products'), findsNothing);
      expect(find.text('Follicle Activator Serum'), findsNothing);
      expect(find.text('Add to Kit / Cart'), findsNothing);
    },
  );

  testWidgets('unavailable assessment does not show a score or products', (
    tester,
  ) async {
    var retries = 0;
    const unavailable = AiAssessmentModel(
      isAvailable: false,
      scalpHealthScore: 0,
      stageClassification: '',
      summary: 'AI could not prepare your assessment.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAssessmentCards(
            aiAssessment: unavailable,
            onRefresh: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('AI assessment unavailable'), findsOneWidget);
    expect(find.text('/100'), findsNothing);
    expect(find.text('Targeted Regimen Products'), findsNothing);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  test('unavailable API payload parses without a fallback stage or score', () {
    final assessment = AiAssessmentModel.fromJson({
      'ai_status': 'unavailable',
      'scalp_health_score': null,
      'stage_classification': null,
      'generated_by': 'unavailable',
      'next_step_recommendation': {
        'type': 'doctor_appointment',
        'reason': 'Reported scalp symptoms deserve clinician review.',
      },
      'recommended_regimen': {
        'daily_steps': [],
        'target_products': [
          {'name': 'Made up product', 'category': 'Serums', 'reason': ''},
        ],
      },
    });

    expect(assessment.isAvailable, isFalse);
    expect(assessment.scalpHealthScore, 0);
    expect(assessment.stageClassification, isEmpty);
    expect(assessment.nextStepType, 'doctor_appointment');
    expect(assessment.recommendedRegimen.targetProducts, isEmpty);
  });
}
