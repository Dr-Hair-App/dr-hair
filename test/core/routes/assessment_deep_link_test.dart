import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:dr_hair/core/constants/app_urls.dart';
import 'package:dr_hair/core/routes/route_names.dart';
import 'package:dr_hair/core/routes/app_router.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_state.dart';
import 'package:dr_hair/features/hair_test/domain/models/ai_assessment_model.dart';
import 'package:dr_hair/features/hair_test/presentation/widgets/assessment_recommendation_card.dart';

void main() {
  group('Assessment Deep-Linking & AppUrls', () {
    test('generates valid in-app custom scheme and universal deep links', () {
      const ref = 'HT-2026-XYZ123';

      expect(
        AppUrls.assessmentAppDeepLink(ref),
        'drhair://hair-test/assessment/HT-2026-XYZ123',
      );
      expect(
        AppUrls.assessmentUniversalLink(ref),
        'https://drhairindia.com/assessment/HT-2026-XYZ123',
      );
      expect(
        AppUrls.patientAssessmentUrl(ref),
        'https://drhairindia.com/assessment/HT-2026-XYZ123',
      );
    });

    test('handles empty or whitespace reference numbers cleanly without crashes', () {
      expect(
        AppUrls.assessmentAppDeepLink('   '),
        'drhair://hair-test/assessment',
      );
      expect(
        AppUrls.assessmentUniversalLink('   '),
        'https://drhairindia.com/assessment',
      );
      expect(
        AppUrls.patientAssessmentUrl('   '),
        'https://drhairindia.com/assessment',
      );
    });

    test('admin URLs are strictly reserved and distinct from patient deep links', () {
      final adminUrl = AppUrls.adminPatientDetailUrl('PAT-999', 'HT-2026-XYZ123');
      final patientUrl = AppUrls.assessmentUniversalLink('HT-2026-XYZ123');
      final deepLink = AppUrls.assessmentAppDeepLink('HT-2026-XYZ123');

      expect(adminUrl, contains('admin.drhairindia.com'));
      expect(patientUrl, isNot(contains('admin.drhairindia.com')));
      expect(deepLink, isNot(contains('admin.drhairindia.com')));
      expect(patientUrl, contains('drhairindia.com/assessment/HT-2026-XYZ123'));
      expect(deepLink, contains('drhair://hair-test/assessment/HT-2026-XYZ123'));
    });
  });

  group('RouteNames Assessment Paths', () {
    test('constructs proper route paths for assessment deep links', () {
      expect(RouteNames.hairTestAssessment, '/hair-test/assessment/:refNo');
      expect(RouteNames.universalAssessment, '/assessment/:refNo');

      expect(
        RouteNames.hairTestAssessmentPath('HT-456'),
        '/hair-test/assessment/HT-456',
      );
      expect(
        RouteNames.universalAssessmentPath('HT-456'),
        '/assessment/HT-456',
      );
    });
  });

  group('AppRouter Deep Link Navigation', () {
    test('router matches custom scheme path and universal link routes', () {
      final router = AppRouter.router;

      final matchHairTest = router.routeInformationParser.configuration.findMatch(
        Uri.parse('/hair-test/assessment/HT-DEEP-001'),
      );
      expect(matchHairTest.isNotEmpty, isTrue);

      final matchUniversal = router.routeInformationParser.configuration.findMatch(
        Uri.parse('/assessment/HT-DEEP-002'),
      );
      expect(matchUniversal.isNotEmpty, isTrue);
    });
  });

  group('HairTestCubit loadAssessmentByReference', () {
    test('sets referenceNo and marks state as completed', () async {
      final cubit = HairTestCubit();
      expect(cubit.state.referenceNo, isNull);
      expect(cubit.state.isCompleted, isFalse);

      await cubit.loadAssessmentByReference('HT-DEEP-999');

      expect(cubit.state.referenceNo, 'HT-DEEP-999');
      expect(cubit.state.isCompleted, isTrue);
    });
  });

  group('AssessmentRecommendationCard Patient Link', () {
    testWidgets('displays in-app assessment link and NEVER shows admin URL', (tester) async {
      const refNo = 'HT-2026-RECO1';
      final state = const HairTestState(
        isCompleted: true,
        referenceNo: refNo,
        name: 'Sahil',
      );
      final aiAssessment = const AiAssessmentModel(
        productAvailabilityStatus: 'unavailable',
        scalpHealthScore: 75,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssessmentRecommendationCard(
                state: state,
                aiAssessment: aiAssessment,
                recommendedProducts: const [],
                onConnectWhatsApp: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Ensure the in-app assessment link is displayed
      expect(
        find.textContaining('App Assessment Link: https://drhairindia.com/assessment/$refNo'),
        findsOneWidget,
      );

      // Verify admin URL is strictly NOT displayed
      expect(find.textContaining('admin.drhairindia.com'), findsNothing);
      expect(find.textContaining('Direct Admin Link'), findsNothing);
    });
  });
}
