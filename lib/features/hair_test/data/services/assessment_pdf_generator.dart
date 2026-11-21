import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../presentation/viewmodels/hair_test_state.dart';

class AssessmentPdfGenerator {
  /// Generates an app-created assessment summary. It is not a signed clinical
  /// document; clinician-issued reports are downloaded from the clinical record.
  static Future<Uint8List> buildPdf(
    HairTestState state, {
    String? patientName,
  }) async {
    final doc = pw.Document();
    // Built-in fonts keep PDF generation offline and avoid a font fetch when a
    // patient taps share or print.
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final ai = state.aiAssessment;
    final stageText = ai?.stageClassification.trim().isNotEmpty == true
        ? ai!.stageClassification.trim()
        : (state.stage?.trim().isNotEmpty == true
              ? state.stage!.trim()
              : 'Not provided');
    final scalpCondition = state.dandruff?.trim().isNotEmpty == true
        ? state.dandruff!.trim()
        : 'Not provided';
    final rootCauses =
        ai?.rootCauses
            .map((cause) => '${cause.factor}: ${cause.severity}')
            .toList(growable: false) ??
        const <String>[];
    final dailySteps = ai?.recommendedRegimen.dailySteps ?? const [];

    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final refNo = state.referenceNo?.trim().isNotEmpty == true
        ? state.referenceNo!.trim()
        : 'Not available';

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
              // App-created summary header; avoid implying clinician authorship.
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Dr. Hair',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 20,
                          color: PdfColor.fromInt(0xFF1E293B),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Hair assessment summary',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColor.fromInt(0xFF64748B),
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
                          'AI ASSESSMENT SUMMARY',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 10,
                            color: PdfColor.fromInt(0xFF0F766E),
                          ),
                        ),
                        pw.Text(
                          'Generated from your submitted answers',
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
                          'ASSESSMENT STATUS: ${state.assessmentStatus.toUpperCase().replaceAll('_', ' ')}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColor.fromInt(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 3. Reported answers and possible factors
              pw.Text(
                '1. ASSESSMENT SUMMARY',
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
                          'Reported / assessed pattern: ',
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
                      'Possible factors from the AI assessment:',
                      style: pw.TextStyle(font: fontBold, fontSize: 9.5),
                    ),
                    pw.SizedBox(height: 2),
                    if (rootCauses.isEmpty)
                      pw.Text(
                        'No possible factors were returned.',
                        style: pw.TextStyle(font: font, fontSize: 8.5),
                      )
                    else
                      ...rootCauses.map(
                        (rc) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 8, top: 1.5),
                          child: pw.Text(
                            '- $rc',
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

              if (dailySteps.isNotEmpty) ...[
                pw.Text(
                  '2. AI-GENERATED ROUTINE',
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
                      border: pw.Border.all(
                        color: PdfColor.fromInt(0xFFE2E8F0),
                      ),
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
              ],

              pw.Spacer(),

              // This summary has no clinician signature.
              pw.Divider(color: PdfColor.fromInt(0xFFCBD5E1), thickness: 1),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AI-generated from your submitted assessment answers.',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 7.5,
                          color: PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                      pw.Text(
                        'This is not a diagnosis, prescription, or signed clinician report.',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 7.5,
                          color: PdfColor.fromInt(0xFF64748B),
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
      name: 'Dr_Hair_Assessment_Summary_${state.referenceNo ?? "Summary"}',
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
      filename:
          'Dr_Hair_Assessment_Summary_${state.referenceNo ?? "Summary"}.pdf',
    );
  }
}
