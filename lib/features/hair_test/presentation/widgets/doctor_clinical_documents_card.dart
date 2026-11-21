import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../treatment/presentation/widgets/clinical_report_card.dart';
import '../../../treatment/presentation/widgets/clinical_report_viewer_sheet.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_cubit.dart';

/// Renders doctor clinical report attachments using the unified [ClinicalReportCard]
/// matching Home and Treatment Reports screens, with interactive View PDF and Order Kit actions.
class DoctorClinicalDocumentsCard extends StatefulWidget {
  final List<Map<String, dynamic>> reports;
  final AssessmentLanguage language;

  const DoctorClinicalDocumentsCard({
    super.key,
    required this.reports,
    this.language = AssessmentLanguage.english,
  });

  @override
  State<DoctorClinicalDocumentsCard> createState() =>
      _DoctorClinicalDocumentsCardState();
}

class _DoctorClinicalDocumentsCardState
    extends State<DoctorClinicalDocumentsCard> {
  String? _loadingReportId;

  Future<void> _handleReportTap(
    String reportId,
    String title,
    String fileName,
  ) async {
    if (_loadingReportId != null) return;
    setState(() => _loadingReportId = reportId);
    try {
      final cubit = context.read<HairTestCubit?>();
      final token = cubit?.sessionToken;
      final api = cubit?.clinicalApi;

      if (token != null &&
          token.isNotEmpty &&
          api != null &&
          reportId.isNotEmpty) {
        await showClinicalReportViewer(
          context,
          api: api,
          accessToken: token,
          reportId: reportId,
          reportName: title,
          fileName: fileName,
        );
      } else {
        final uri = await cubit?.getReportDownloadUri(reportId);
        if (uri != null && mounted) {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (_) {
      // Fallback silently if viewer dismissed or failed
    } finally {
      if (mounted) setState(() => _loadingReportId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unified Clinical Documents Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                LucideIcons.fileCheck2,
                color: Color(0xFF16A34A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AssessmentTranslations.t(
                      'clinical_documents',
                      widget.language,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    AssessmentTranslations.t(
                      'shared_with_care_team',
                      widget.language,
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // List of Clinical Reports matching Home & Treatment details
        ...widget.reports.map((report) {
          final String title =
              report['title']?.toString() ?? 'Clinical Hair & Scalp Report';
          final String fileName =
              report['file_name']?.toString().trim().isNotEmpty == true
                  ? report['file_name'].toString()
                  : 'clinical-report.pdf';
          final String reportId = report['id']?.toString() ?? '';
          final num? bytes = report['bytes'] as num?;
          final String sizeStr = bytes == null || bytes < 0
              ? 'Size unavailable'
              : bytes / 1024 < 1000
                  ? '${(bytes / 1024).toStringAsFixed(0)} KB'
                  : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          final String uploadedBy =
              report['uploaded_by']?.toString().trim().isNotEmpty == true
                  ? 'Shared by ${report['uploaded_by']}'
                  : 'Shared by Dr. Hair Clinic';
          final String uploadDate = report['upload_date']?.toString() ??
              report['created_at']?.toString() ??
              'Recent';
          final String? subtitle = report['description']?.toString() ??
              report['subtitle']?.toString();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClinicalReportCard(
                  title: title,
                  fileName: fileName,
                  fileSize: sizeStr,
                  uploadedBy: uploadedBy,
                  uploadDate: uploadDate,
                  subtitle: subtitle,
                  isNew: true,
                  isLoading: _loadingReportId == reportId,
                  actionLabel:
                      AssessmentTranslations.t('view_pdf', widget.language),
                  onTap: () => _handleReportTap(reportId, title, fileName),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        height: 38,
                        text: AssessmentTranslations.t(
                          'view_pdf',
                          widget.language,
                        ),
                        variant: AppButtonVariant.outlined,
                        borderColor: const Color(0xFFBBF7D0),
                        foregroundColor: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(
                          LucideIcons.fileText,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        onPressed: () =>
                            _handleReportTap(reportId, title, fileName),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        height: 38,
                        text: AssessmentTranslations.t(
                          'order_kit',
                          widget.language,
                        ),
                        variant: AppButtonVariant.filled,
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        icon: const Icon(
                          LucideIcons.shoppingBag,
                          size: 14,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          context.push(RouteNames.products);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
