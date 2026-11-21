import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:dr_hair/features/hair_test/presentation/localization/assessment_translations.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_cubit.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_state.dart';
import 'package:dr_hair/features/hair_test/presentation/views/assessment_report_view.dart';
import 'package:dr_hair/features/hair_test/presentation/widgets/scalp_photos_gallery_card.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/products_cubit.dart';
import 'package:dr_hair/features/shop/presentation/viewmodels/products_state.dart';

Widget _wrapWithProviders(Widget child, {HairTestCubit? cubit}) {
  final testCubit = cubit ?? HairTestCubit();
  return MultiBlocProvider(
    providers: [
      BlocProvider<HairTestCubit>.value(value: testCubit),
      BlocProvider<ProductsCubit>(
        create: (_) => ProductsCubit(
          initialState: const ProductsState(products: []),
        ),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('AssessmentTranslations Unit Tests', () {
    test('static key translations return accurate values across EN, HI, Hinglish', () {
      expect(
        AssessmentTranslations.t('assessment_report_title', AssessmentLanguage.english),
        'Assessment Report',
      );
      expect(
        AssessmentTranslations.t('assessment_report_title', AssessmentLanguage.hindi),
        'हेयर असेसमेंट रिपोर्ट',
      );
      expect(
        AssessmentTranslations.t('assessment_report_title', AssessmentLanguage.hinglish),
        'Assessment Report',
      );

      expect(
        AssessmentTranslations.t('clinical_scalp_photos', AssessmentLanguage.english),
        'Clinical Scalp Photos',
      );
      expect(
        AssessmentTranslations.t('clinical_scalp_photos', AssessmentLanguage.hindi),
        'स्कैल्प की क्लिनिकल तस्वीरें',
      );
      expect(
        AssessmentTranslations.t('clinical_scalp_photos', AssessmentLanguage.hinglish),
        'Aapke Scalp Photos',
      );
    });

    test('dynamic scalp score text generates correct localized phrasing', () {
      final en = AssessmentTranslations.getScalpScoreText(68, AssessmentLanguage.english);
      final hi = AssessmentTranslations.getScalpScoreText(68, AssessmentLanguage.hindi);
      final hinglish = AssessmentTranslations.getScalpScoreText(68, AssessmentLanguage.hinglish);

      expect(en, contains('Your scalp health score is 68/100'));
      expect(hi, contains('आपका स्कैल्प हेल्थ स्कोर 68/100 है'));
      expect(hinglish, contains('Aapka scalp health score 68/100 hai'));
    });

    test('translates stages, severities, and root causes properly', () {
      expect(
        AssessmentTranslations.translateStage('Stage 2 - Receding Hairline', AssessmentLanguage.hindi),
        'स्टेज 2 - पीछे हटती हेयरलाइन',
      );
      expect(
        AssessmentTranslations.translateSeverity('Moderate', AssessmentLanguage.hindi),
        'मध्यम (Moderate)',
      );
      expect(
        AssessmentTranslations.translateRootCauseFactor('DHT Sensitivity', AssessmentLanguage.hindi),
        contains('डीएचटी संवेदनशीलता'),
      );
      expect(
        AssessmentTranslations.translateRootCauseFactor('Nutritional Deficiency', AssessmentLanguage.hinglish),
        contains('Nutritional Deficiency'),
      );
    });
  });

  group('AssessmentReportView Multilingual & Photos Widget Tests', () {
    testWidgets('renders multilingual language switch button and photos gallery', (tester) async {
      final cubit = HairTestCubit();
      cubit.emit(
        cubit.state.copyWith(
          isCompleted: true,
          isSubmitted: true,
          name: 'Sunil Kumar',
          age: '28',
          stage: 'Stage 2 - Receding Hairline',
          photos: {
            'front': 'https://example.com/front.jpg',
            'top': 'https://example.com/top.jpg',
          },
        ),
      );

      await tester.pumpWidget(_wrapWithProviders(AssessmentReportView(state: cubit.state), cubit: cubit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Multilingual switcher button is in AssessmentOverviewCard (top of body)
      expect(find.byIcon(LucideIcons.languages), findsOneWidget);

      // Scalp Photos Gallery is displayed prominently
      expect(find.text('Clinical Scalp Photos'), findsOneWidget);
      expect(find.text('Front Hairline'), findsOneWidget);
      expect(find.text('Top View'), findsOneWidget);

      // Open Language Selector Sheet
      await tester.tap(find.byIcon(LucideIcons.languages));
      await tester.pumpAndSettle();

      expect(find.text('Select Language / भाषा चुनें'), findsOneWidget);
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('Hinglish'), findsOneWidget);

      // Tap Hindi option
      await tester.tap(find.text('हिंदी'));
      await tester.pumpAndSettle();

      // UI switches to Hindi – report title and Retest button in bottom bar
      expect(find.text('हेयर असेसमेंट रिपोर्ट'), findsOneWidget);
      expect(find.text('पुनः जाँच'), findsOneWidget);

      cubit.close();
    });

    testWidgets('ScalpPhotosGalleryCard shows missing placeholder when photo is absent', (tester) async {
      const state = HairTestState(photos: {});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScalpPhotosGalleryCard(state: state),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No scalp photos attached'), findsOneWidget);
    });
  });
}
