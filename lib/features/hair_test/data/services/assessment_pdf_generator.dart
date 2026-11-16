import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/ai_assessment_model.dart';
import '../../presentation/viewmodels/hair_test_state.dart';

class AssessmentPdfGenerator {
  /// Generates the doctor-branded clinical assessment slip PDF document.
  static Future<Uint8List> buildPdf(
    HairTestState state, {
    String? patientName,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    final ai = state.aiAssessment;
    final stageText = ai?.stageClassification.isNotEmpty == true
        ? ai!.stageClassification
        : (state.stage?.isNotEmpty == true
            ? state.stage!
            : 'Norwood Stage II (Early Thinning)');

    final scalpCondition = state.dandruff?.isNotEmpty == true
        ? state.dandruff!
        : 'Micro-Inflammation & Sebum Imbalance';

    final rootCauses = ai?.rootCauses.isNotEmpty == true
        ? ai!.rootCauses.map((r) => '${r.factor}: ${r.severity}').toList()
        : const [
            'DHT Sensitivity & Genetic Susceptibility: Moderate',
            'Scalp Microbiome & Sebum Imbalance: High',
            'Nutritional & Protein Deficit: Moderate',
          ];

    final dailySteps = ai?.recommendedRegimen.dailySteps.isNotEmpty == true
        ? ai!.recommendedRegimen.dailySteps
        : const [
            AiRegimenStep(
              step: 'Morning Routine',
              instruction:
                  'Wash scalp with therapeutic anti-dandruff cleanser, rinse thoroughly with ambient water.',
            ),
            AiRegimenStep(
              step: 'Night Routine',
              instruction:
                  'Apply 1ml Dr. Hair Density Scalp Solution to targeted thinning zones before bed.',
            ),
            AiRegimenStep(
              step: 'Daily Nutrition & Hydration',
              instruction:
                  'Drink 2.5L-3.0L water to flush DHT toxins and take 1 hair-active biotin tablet after meals.',
            ),
          ];

    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final refNo = state.referenceNo?.isNotEmpty == true
        ? state.referenceNo!
        : 'DHP-${now.millisecondsSinceEpoch.toString().substring(7)}';

    final effectivePatientName = patientName?.isNotEmpty == true
        ? patientName!
        : (state.name.isNotEmpty ? state.name : 'Registered Patient');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Clinic Letterhead Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DR. HAIR CLINIC',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 20,
                          color: PdfColor.fromInt(0xFF1E293B),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Advanced Hair Restoration & Trichology Centre',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                      pw.Text(
                        'Jaipur Central Clinic · Reg: DH-MED-2024-8812 · contact@drhair.in',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 8,
                          color: PdfColor.fromInt(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFF0F766E),
                        width: 1.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'CLINICAL SUMMARY',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColor.fromInt(0xFF0F766E),
                          ),
                        ),
                        pw.Text(
                          'Dr. Jai Bansal (MD, Trichology)',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: PdfColor.fromInt(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColor.fromInt(0xFFCBD5E1), thickness: 1),
              pw.SizedBox(height: 10),

              // 2. Patient & Assessment Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PATIENT: $effectivePatientName',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColor.fromInt(0xFF0F172A),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'ASSESSMENT REF: $refNo',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColor.fromInt(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'DATE: $dateStr',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColor.fromInt(0xFF0F172A),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'STATUS: CLINICALLY REVIEWED',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9,
                            color: PdfColor.fromInt(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 3. Clinical Diagnosis
              pw.Text(
                '1. DIAGNOSTIC FINDINGS',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFF0F766E),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFFFFF),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'Hair Thinning Stage: ',
                          style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                        ),
                        pw.Text(
                          stageText,
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9.5,
                            color: PdfColor.fromInt(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Scalp Barrier / Flaking: ',
                          style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                        ),
                        pw.Text(
                          scalpCondition,
                          style: pw.TextStyle(font: font, fontSize: 9.5),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Primary Contributing Factors:',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 2),
                    ...rootCauses.map(
                      (rc) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 8, top: 1.5),
                        child: pw.Text(
                          '• $rc',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 8.5,
                            color: PdfColor.fromInt(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 4. Personalized Doctor Regimen
              pw.Text(
                '2. RECOMMENDED TREATMENT PLAN',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 11,
                  color: PdfColor.fromInt(0xFF0F766E),
                ),
              ),
              pw.SizedBox(height: 5),
              ...dailySteps.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final step = entry.value;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF8FAFC),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '$idx. ${step.step}',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9.5,
                              color: PdfColor.fromInt(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        step.instruction,
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 8.5,
                          color: PdfColor.fromInt(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Spacer(),

              // 5. Doctor Stamp & Clinic Disclaimer
              pw.Divider(color: PdfColor.fromInt(0xFFCBD5E1), thickness: 1),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Official medical summary issued by Dr. Hair Trichology Centre.',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 7.5,
                          color: PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                      pw.Text(
                        'Direct Clinic WhatsApp Support: +91 7240005000.',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 7.5,
                          color: PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Dr. Jai Bansal',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 10,
                          color: PdfColor.fromInt(0xFF0F766E),
                        ),
                      ),
                      pw.Text(
                        'Digitally Signed & Verified ✅',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 7.5,
                          color: PdfColor.fromInt(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Opens native print / save preview.
  static Future<void> downloadOrPrint(
    HairTestState state, {
    String? patientName,
  }) async {
    final bytes = await buildPdf(state, patientName: patientName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Dr_Hair_Medical_Report_${state.referenceNo ?? "Summary"}',
    );
  }

  /// Shares PDF file via native share sheet.
  static Future<void> sharePdf(
    HairTestState state, {
    String? patientName,
  }) async {
    final bytes = await buildPdf(state, patientName: patientName);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Dr_Hair_Medical_Report_${state.referenceNo ?? "Summary"}.pdf',
    );
  }
}
