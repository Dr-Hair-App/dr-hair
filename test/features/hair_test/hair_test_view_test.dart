import 'package:dr_hair/core/storage/app_local_cache.dart';
import 'package:dr_hair/features/hair_test/domain/models/hair_photo_analysis.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/hair_test/presentation/views/hair_test_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets(
    'restores allergy, medication, and condition text on the safety step',
    (tester) async {
      final cubit = HairTestCubit();
      cubit.emit(
        cubit.state.copyWith(
          currentStep: 8,
          allergyStatus: 'Yes, I have allergies',
          allergyDetails: 'Penicillin',
          currentMedicationsStatus: 'Yes',
          currentMedications: 'Vitamin D',
          medicalConditions: 'Thyroid condition',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextFormField>(
        find.byType(TextFormField),
      );
      expect(
        fields.map((field) => field.initialValue),
        containsAll(['Penicillin', 'Vitamin D', 'Thyroid condition']),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
    },
  );

  testWidgets('shows branded custom-painted waiting screen during AI work', (
    tester,
  ) async {
    final cubit = HairTestCubit();
    cubit.emit(cubit.state.copyWith(isSubmitting: true));

    await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));

    expect(find.text('Dr. Hair Assistant'), findsOneWidget);
    expect(find.text('Putting your care pathway together'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.textContaining('Gemini'), findsNothing);
    expect(find.text('Assessment Report'), findsNothing);

    await tester.pump(const Duration(seconds: 25));
    expect(find.text('This is taking longer than usual.'), findsOneWidget);
    expect(find.text('Contact the clinic'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  testWidgets('respects reduce-motion settings on the waiting screen', (
    tester,
  ) async {
    final cubit = HairTestCubit();
    cubit.emit(cubit.state.copyWith(isSubmitting: true));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: HairTestView(cubit: cubit),
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.clock3), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });

  testWidgets(
    'HairTestView navigation buttons smoothly animate and allow step transitions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HairTestView()));

      // Initial step 0: Continue is present, Back button is not displayed
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Back'), findsNothing);

      // The first question is required before the assessment can continue.
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 10'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Stage 1'));
      await tester.tap(find.text('Stage 1'));
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Now on step 2: Back button should be visible
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Tap Back to return to step 0
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Back on step 0: Back button is smoothly hidden again
      expect(find.text('Back'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
    },
  );

  testWidgets(
    'HairTestView opens questionnaire on app start even when previous test was completed (report not shown repeatedly)',
    (tester) async {
      final cubit = HairTestCubit();
      // Simulate previously completed test saved state
      cubit.selectPrimaryConcern('Stage 1 - Receding hairline at temples');
      await cubit.skipPhotosAndSubmit();
      expect(cubit.state.isCompleted, isTrue);

      // Dismiss report as would happen after user views it
      cubit.dismissReport();
      expect(cubit.state.isSubmitted, isFalse);

      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pumpAndSettle();

      // Should show Step 1 Questionnaire, NOT Assessment Report
      expect(find.text('Hair & Scalp Assessment'), findsOneWidget);
      expect(find.text('Step 1 of 10'), findsOneWidget);
      expect(find.text('Assessment complete'), findsNothing);
      expect(find.text('Your Hair Loss Root Causes'), findsNothing);

      cubit.close();
    },
  );

  testWidgets(
    'Assessment Report has no bottom price bar and shows practical clinical actions',
    (tester) async {
      final cubit = HairTestCubit();
      cubit.selectGender('Male');
      cubit.selectPrimaryConcern('Stage 1 - Receding hairline at temples');
      await cubit.skipPhotosAndSubmit();
      expect(cubit.state.isSubmitted, isTrue);

      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Report is displayed once submitted
      expect(find.text('Assessment Report'), findsOneWidget);
      expect(find.text('Your assessment is ready'), findsOneWidget);
      expect(find.text('Assessment Submitted'), findsOneWidget);
      expect(find.textContaining('Dr. Jai Bansal'), findsNothing);

      // Bottom price bar elements must NOT exist
      expect(find.text('₹1445'), findsNothing);
      expect(find.text('₹2044'), findsNothing);
      expect(find.text('Inclusive of all taxes'), findsNothing);
      expect(find.text('Buy Now'), findsNothing);
      expect(find.textContaining('GMP & ISO'), findsNothing);

      cubit.close();
    },
  );

  testWidgets(
    'Assessment Report displays Clinical Scalp Photos and doctor review timeline',
    (tester) async {
      final cubit = HairTestCubit();
      cubit.selectGender('Male');
      cubit.selectPrimaryConcern('Stage 1 - Receding hairline at temples');
      await cubit.skipPhotosAndSubmit();
      expect(cubit.state.isSubmitted, isTrue);

      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Clinical Scalp Photos'), findsOneWidget);
      expect(find.text('Intake Done'), findsOneWidget);
      expect(find.text('AI Review Done'), findsOneWidget);
      expect(find.text('Doctor Review'), findsOneWidget);

      cubit.close();
    },
  );

  testWidgets(
    'Assessment Report renders cleanly without overflow on small 320x568 screen',
    (tester) async {
      FlutterErrorDetails? caughtDetails;
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        prevOnError?.call(details);
      };

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        FlutterError.onError = prevOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cubit = HairTestCubit();
      cubit.selectGender('Male');
      cubit.selectPrimaryConcern('Stage 1 - Receding hairline at temples');
      await cubit.skipPhotosAndSubmit();

      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Assessment Report'), findsOneWidget);
      expect(find.text('WHAT YOU SHARED'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(caughtDetails, isNull);

      cubit.close();
    },
  );

  testWidgets(
    'HairTestView displays detection badge and contextual message for hair vs non-hair images',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cubit = HairTestCubit();
      // Fast forward to the final step (Upload Scalp Photos)
      cubit.selectPrimaryConcern('Stage 1 - Receding hairline at temples');
      cubit.selectDuration('1 - 3 years');
      cubit.selectDandruff('Occasional flakes or itching');
      cubit.selectStressLevel('Moderate');
      cubit.selectGutHealth('Normal');
      cubit.selectFamilyHistory("Mother's side");
      cubit.selectHairFallTrend('No, it has been gradual or stable');
      cubit.selectScalpSymptoms('No');
      cubit.setAllergyStatus('No known allergies');
      cubit.setCurrentMedicationsStatus('No');

      const frontPath = '/tmp/front_scalp.jpg';
      const crownPath = '/tmp/non_hair_car.jpg';
      cubit.emit(
        cubit.state.copyWith(
          currentStep: 9,
          photos: const {'Front Hairline': frontPath, 'Crown / Top': crownPath},
          optimizedPhotos: const {
            'Front Hairline': frontPath,
            'Crown / Top': crownPath,
          },
          photoAnalysis: {
            'Front Hairline': HairPhotoAnalysis(
              label: 'Front Hairline',
              photoPath: frontPath,
              status: HairDetectionStatus.hairDetected,
              confidence: 0.95,
              message: 'Scalp confirmed',
              details: 'A clear scalp photo was detected.',
            ),
            'Crown / Top': HairPhotoAnalysis(
              label: 'Crown / Top',
              photoPath: crownPath,
              status: HairDetectionStatus.notHair,
              confidence: 0.9,
              message: 'Try another photo',
              details: 'The image does not show a scalp.',
            ),
          },
        ),
      );
      expect(cubit.state.currentStep, 9);

      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Step header
      expect(find.text('Scalp photos'), findsOneWidget);

      // Warning banner for flagged non-hair photo
      expect(
        find.text(
          'One or more photos do not clearly show the scalp. Retake them for a better assessment.',
        ),
        findsOneWidget,
      );

      // Front Hairline (Hair detected - minimal verified badge)
      expect(find.byIcon(LucideIcons.check), findsWidgets);
      expect(find.text('Scalp confirmed'), findsOneWidget);

      // Crown / Top (Non-hair image - minimal not scalp badge)
      expect(find.text('Try another photo'), findsOneWidget);
      expect(find.text('Change'), findsWidgets);

      cubit.close();
    },
  );

  testWidgets(
    'HairTestView displays different person badge and alert banner when photos belong to different people',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cubit = HairTestCubit();
      cubit.selectPrimaryConcern('Stage 1 - Receding hairline at temples');
      cubit.selectDuration('1 - 3 years');
      cubit.selectDandruff('Occasional flakes or itching');
      cubit.selectStressLevel('Moderate');
      cubit.selectGutHealth('Normal');
      cubit.selectFamilyHistory("Mother's side");
      cubit.selectHairFallTrend('No, it has been gradual or stable');
      cubit.selectScalpSymptoms('No');
      cubit.setAllergyStatus('No known allergies');
      cubit.setCurrentMedicationsStatus('No');

      const frontPath = '/tmp/front_scalp.jpg';
      const crownPath = '/tmp/different_person_crown.jpg';
      cubit.emit(
        cubit.state.copyWith(
          currentStep: 9,
          photos: const {'Front Hairline': frontPath, 'Crown / Top': crownPath},
          optimizedPhotos: const {
            'Front Hairline': frontPath,
            'Crown / Top': crownPath,
          },
          photoAnalysis: {
            'Front Hairline': const HairPhotoAnalysis(
              label: 'Front Hairline',
              photoPath: frontPath,
              status: HairDetectionStatus.hairDetected,
              confidence: 0.95,
              message: 'Scalp confirmed',
              details: 'Clear scalp photo.',
            ),
            'Crown / Top': const HairPhotoAnalysis(
              label: 'Crown / Top',
              photoPath: crownPath,
              status: HairDetectionStatus.personMismatch,
              confidence: 0.96,
              message:
                  'Photos appear to be of different people. Please ensure all 3 photos are of the same person.',
              details: 'Hair texture and skin tone do not match.',
            ),
          },
        ),
      );

      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Photos appear to be of different people. Please ensure all 3 photos belong to the same person.',
        ),
        findsOneWidget,
      );

      expect(find.text('Different person'), findsOneWidget);
      expect(find.byIcon(LucideIcons.userX), findsWidgets);

      cubit.close();
    },
  );

  testWidgets(
    'HairTestView skip button marks assessment as skipped in local cache',
    (tester) async {
      await AppLocalCache.instance.clearAll();

      final cubit = HairTestCubit();
      await tester.pumpWidget(MaterialApp(home: HairTestView(cubit: cubit)));
      await tester.pumpAndSettle();

      final skipFinder = find.text('Skip');
      expect(skipFinder, findsOneWidget);

      await tester.tap(skipFinder);
      await tester.pumpAndSettle();

      expect(AppLocalCache.instance.getBool('has_skipped_hair_test'), isTrue);

      cubit.close();
    },
  );
}
