import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:dr_hair/core/theme/app_theme.dart';
import 'package:dr_hair/features/home/domain/models/home_action_card.dart';
import 'package:dr_hair/features/home/presentation/viewmodels/home_summary_cubit.dart';
import 'package:dr_hair/features/home/presentation/viewmodels/home_summary_state.dart';
import 'package:dr_hair/features/home/presentation/widgets/home_action_cards_section.dart';
import 'package:dr_hair/features/treatment/data/patient_clinical_api.dart';

class _MockHomeSummaryCubit extends HomeSummaryCubit {
  _MockHomeSummaryCubit(HomeSummaryState initialState)
      : super(clinicalApi: _DummyClinicalApi()) {
    emit(initialState);
  }
}

class _DummyClinicalApi extends Fake implements PatientClinicalApi {}

void main() {
  Widget buildCardsSection(HomeSummaryCubit cubit) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeActionCardsSection(cubit: cubit),
        ),
      ),
    );
  }

  group('HomeActionCardsSection', () {
    testWidgets('renders Skeletonizer placeholder when loading with no cards', (tester) async {
      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: true,
        data: HomeSummaryData(),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pump();

      expect(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
        findsOneWidget,
      );
    });

    testWidgets('renders nothing when state has no cards and not loading', (tester) async {
      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: false,
        data: HomeSummaryData(),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
        findsNothing,
      );
      expect(find.text('Urgent Clinic Evaluation Recommended'), findsNothing);
    });

    testWidgets('renders Priority 1: Clinician urgent action card', (tester) async {
      const urgentCard = HomeActionCard(
        id: 'card-1',
        type: 'clinician_urgent',
        priority: 100,
        title: 'Urgent Clinic Evaluation Recommended',
        body: 'Rapid progressive thinning detected. Please consult a clinician.',
        actionLabel: 'Book Clinic Consultation',
        destinationRoute: '/clinic-appointment',
        whyShown: 'Clinical flag: rapid thinning',
      );

      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: false,
        data: HomeSummaryData(actionCards: [urgentCard]),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Urgent Clinic Evaluation Recommended'), findsOneWidget);
      expect(find.text('Rapid progressive thinning detected. Please consult a clinician.'), findsOneWidget);
      expect(find.text('Book Clinic Consultation'), findsOneWidget);
      expect(find.text('Clinical flag: rapid thinning'), findsOneWidget);
    });

    testWidgets('renders Priority 2: Pending assessment card', (tester) async {
      const pendingAssessmentCard = HomeActionCard(
        id: 'card-2',
        type: 'pending_assessment',
        priority: 90,
        title: 'Complete Your Free Hair Test',
        body: 'You have an unfinished assessment.',
        actionLabel: 'Continue Assessment',
        destinationRoute: '/hair-test',
        whyShown: 'Assessment draft saved',
      );

      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: false,
        data: HomeSummaryData(actionCards: [pendingAssessmentCard]),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Free Hair Test'), findsOneWidget);
      expect(find.text('You have an unfinished assessment.'), findsOneWidget);
      expect(find.text('Continue Assessment'), findsOneWidget);
      expect(find.text('Assessment draft saved'), findsOneWidget);
    });

    testWidgets('renders Priority 3: Shared report card with open action', (tester) async {
      const sharedReportCard = HomeActionCard(
        id: 'card-3',
        type: 'shared_report',
        priority: 80,
        title: 'New report from clinic',
        body: 'A doctor-reviewed diagnostic report has been shared with you.',
        actionLabel: 'Open report',
        entityId: 'rep-999',
        whyShown: 'Shared diagnostic report available',
      );

      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: false,
        data: HomeSummaryData(actionCards: [sharedReportCard]),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pumpAndSettle();

      expect(find.text('New report from clinic'), findsOneWidget);
      expect(find.text('A doctor-reviewed diagnostic report has been shared with you.'), findsOneWidget);
      expect(find.text('Open report'), findsOneWidget);
      expect(find.text('View in records'), findsOneWidget);
      expect(find.text('Shared diagnostic report available'), findsOneWidget);
    });

    testWidgets('renders Priority 4: Doctor-authored care plan card', (tester) async {
      const carePlanCard = HomeActionCard(
        id: 'card-4',
        type: 'care_plan',
        priority: 70,
        title: 'Your care plan',
        body: 'Your personalized 90-day regrowth protocol is ready.',
        actionLabel: 'View plan',
        entityId: 'cp-888',
        whyShown: 'Active medical care plan',
      );

      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: false,
        data: HomeSummaryData(actionCards: [carePlanCard]),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Your care plan'), findsOneWidget);
      expect(find.text('Your personalized 90-day regrowth protocol is ready.'), findsOneWidget);
      expect(find.text('View plan'), findsOneWidget);
      expect(find.text('Active medical care plan'), findsOneWidget);
    });

    testWidgets('renders Priority 5: Product suggestions card with products', (tester) async {
      const productsCard = HomeActionCard(
        id: 'card-5',
        type: 'product_suggestions',
        priority: 60,
        title: 'Recommended For Your Assessment',
        body: 'Targeted scalp care based on your analysis.',
        actionLabel: 'View Recommended Products',
        whyShown: 'AI assessment recommended',
        products: [
          {
            'id': 'prod-1',
            'name': 'Anti-DHT Scalp Serum',
            'price': 899,
          },
          {
            'id': 'prod-2',
            'name': 'Biotin Growth Shampoo',
            'price': 499,
          },
        ],
      );

      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: false,
        data: HomeSummaryData(actionCards: [productsCard]),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Recommended For Your Assessment'), findsOneWidget);
      expect(find.text('Anti-DHT Scalp Serum'), findsOneWidget);
      expect(find.text('₹899'), findsOneWidget);
      expect(find.text('Biotin Growth Shampoo'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('View Recommended Products'), findsOneWidget);
    });

    testWidgets('renders Priority 6: Appointment suggestion card', (tester) async {
      const appointmentCard = HomeActionCard(
        id: 'card-6',
        type: 'appointment_suggestion',
        priority: 50,
        title: 'Doctor Consultation Recommended',
        body: 'Your assessment pattern suggests evaluating with a specialist.',
        actionLabel: 'Book Appointment',
        destinationRoute: '/clinic-appointment',
        whyShown: 'Assessment suggested clinical consult',
      );

      final cubit = _MockHomeSummaryCubit(const HomeSummaryState(
        isLoading: false,
        data: HomeSummaryData(actionCards: [appointmentCard]),
      ));

      await tester.pumpWidget(buildCardsSection(cubit));
      await tester.pumpAndSettle();

      expect(find.text('Doctor Consultation Recommended'), findsOneWidget);
      expect(find.text('Book Appointment'), findsOneWidget);
      expect(find.text('Assessment suggested clinical consult'), findsOneWidget);
    });
  });
}
