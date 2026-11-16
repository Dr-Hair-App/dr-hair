import 'package:flutter_test/flutter_test.dart';
import 'package:dr_hair/features/hair_test/data/services/assessment_pdf_generator.dart';
import 'package:dr_hair/features/hair_test/domain/models/ai_assessment_model.dart';
import 'package:dr_hair/features/hair_test/presentation/viewmodels/hair_test_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssessmentPdfGenerator Tests', () {
    test('buildPdf produces valid PDF byte stream with magic header %PDF', () async {
      const sampleState = HairTestState(
        isCompleted: true,
        name: 'Rahul Sharma',
        age: '26',
        stage: 'Stage 2 - Receding Hairline',
        dandruff: 'Severe Dandruff & Flakes',
        referenceNo: 'DHP-998822',
        aiAssessment: AiAssessmentModel(
          scalpHealthScore: 72,
          stageClassification: 'Norwood Stage 2 - Early Thinning',
          summary: 'Temples thinning with mild sebum scaling.',
          rootCauses: [
            AiRootCause(
              factor: 'DHT Sensitivity',
              severity: 'Moderate',
              explanation: 'Temple follicles vulnerable to DHT miniaturization.',
            ),
          ],
        ),
      );

      final pdfBytes = await AssessmentPdfGenerator.buildPdf(
        sampleState,
        patientName: 'Rahul Sharma',
      );

      expect(pdfBytes, isNotEmpty);
      // Valid PDF files start with the magic ASCII header '%PDF' (0x25, 0x50, 0x44, 0x46)
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });

    test('buildPdf handles empty/fallback state gracefully', () async {
      const emptyState = HairTestState();

      final pdfBytes = await AssessmentPdfGenerator.buildPdf(emptyState);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], equals(0x25)); // %
      expect(pdfBytes[1], equals(0x50)); // P
      expect(pdfBytes[2], equals(0x44)); // D
      expect(pdfBytes[3], equals(0x46)); // F
    });
  });
}
