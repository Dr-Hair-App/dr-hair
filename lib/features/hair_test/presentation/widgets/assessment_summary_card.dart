import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../viewmodels/hair_test_state.dart';

/// Reusable Patient Assessment Summary Card for Home Screen and Shell.
/// Displays the patient's diagnosed hair loss stage, scalp health score,
/// and contextual actions (e.g. View Report, Book Doctor Consult, Daily Routine).
class AssessmentSummaryCard extends StatelessWidget {
  final HairTestState state;
  final VoidCallback? onViewReport;

  const AssessmentSummaryCard({
    super.key,
    required this.state,
    this.onViewReport,
  });

  @override
  Widget build(BuildContext context) {
    final aiAssessment = state.aiAssessment;
    final bool isCritical = aiAssessment?.isCritical ?? (aiAssessment?.nextStepType == 'doctor_appointment');
    final score = aiAssessment?.scalpHealthScore ?? 70;
    final stage = aiAssessment?.stageClassification.isNotEmpty == true
        ? aiAssessment!.stageClassification
        : (state.stage ?? 'Stage 2 - Early Thinning');

    final Color badgeBg = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final Color badgeBorder = isCritical ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0);
    final Color badgeText = isCritical ? const Color(0xFFB91C1C) : const Color(0xFF047857);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isCritical ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isCritical ? LucideIcons.alertCircle : LucideIcons.shieldCheck,
                      size: 13,
                      color: badgeText,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isCritical ? 'Priority Consult' : 'Assessment Ready',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.referenceNo?.isNotEmpty == true)
                Text(
                  'Ref: ${state.referenceNo}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Scalp Health Score Circle
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCritical
                      ? const Color(0xFFFEF2F2)
                      : AppColors.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: isCritical
                        ? const Color(0xFFEF4444)
                        : AppColors.primary,
                    width: 2.2,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isCritical
                              ? const Color(0xFFDC2626)
                              : AppColors.primary,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'SCORE',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isCritical
                          ? 'Clinical Trichologist appointment strongly recommended'
                          : (aiAssessment?.summary.isNotEmpty == true
                              ? aiAssessment!.summary
                              : 'Personalized hair care regimen and guidance ready'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onViewReport ??
                      () => context.push(RouteNames.assessmentResult),
                  icon: const Icon(LucideIcons.fileText, size: 16),
                  label: const Text(
                    'View Report',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCritical ? const Color(0xFFD97706) : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (isCritical) {
                      context.push(RouteNames.clinicAppointment);
                    } else {
                      context.push(RouteNames.routine);
                    }
                  },
                  icon: Icon(
                    isCritical ? LucideIcons.calendarCheck : LucideIcons.listChecks,
                    size: 16,
                  ),
                  label: Text(
                    isCritical ? 'Book Consult' : 'Care Routine',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
