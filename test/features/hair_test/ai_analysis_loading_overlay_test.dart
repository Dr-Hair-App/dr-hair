import 'package:dr_hair/features/hair_test/presentation/widgets/ai_analysis_loading_overlay.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows accessible dancing dots instead of the lower progress bar',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: AiAnalysisLoadingOverlay(uploadProgress: 0.4)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Uploading 40%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.bySemanticsLabel('Uploading assessment'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'announces the AI review phase after multipart upload completes',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(home: AiAnalysisLoadingOverlay(uploadProgress: 1)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(
          'Photos uploaded — checking your scalp and preparing your result',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Checking your scalp and preparing your result'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Checking scalp photos and preparing result'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('keeps dots static when reduced motion is enabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const MaterialApp(
          home: AiAnalysisLoadingOverlay(uploadProgress: 0.2),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel('Uploading assessment'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    semantics.dispose();
  });
}
