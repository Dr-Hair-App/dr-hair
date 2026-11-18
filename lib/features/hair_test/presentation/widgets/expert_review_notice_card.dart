import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_state.dart';

/// Displays the clinical review status banner and 3-step progress timeline
/// (Intake Sent -> Doctor Review -> Regimen Prescribed).
class ExpertReviewNoticeCard extends StatelessWidget {
  final HairTestState state;
  final bool isReviewed;
  final bool isUnderReview;
  final AssessmentLanguage language;

  const ExpertReviewNoticeCard({
    super.key,
    required this.state,
    required this.isReviewed,
    required this.isUnderReview,
    this.language = AssessmentLanguage.english,
  });

  String? _reviewerName(Map<String, dynamic>? plan) {
    if (plan == null) return null;
    for (final key in ['doctor_name', 'reviewed_by']) {
      final value = plan[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Color cardBg;
    Color borderCol;
    Color iconCol;
    IconData iconData;
    String badgeText;
    String title;
    String subtitle;
    String description;

    if (isReviewed) {
      cardBg = const Color(0xFFF0FDF4);
      borderCol = const Color(0xFFBBF7D0);
      iconCol = const Color(0xFF16A34A);
      iconData = LucideIcons.badgeCheck;
      badgeText = AssessmentTranslations.t('clinical_review_completed', language);
      title = AssessmentTranslations.t('clinical_review_is_complete', language);
      final reviewer = _reviewerName(state.doctorCarePlan);
      final reviewerPrefix = AssessmentTranslations.t('reviewed_by', language);
      subtitle = reviewer == null ? '' : '$reviewerPrefix $reviewer';
      description = state.doctorCarePlan != null
          ? AssessmentTranslations.t('care_plan_added', language)
          : AssessmentTranslations.t('clinical_review_recorded', language);
    } else if (isUnderReview) {
      cardBg = const Color(0xFFEFF6FF);
      borderCol = const Color(0xFFBFDBFE);
      iconCol = const Color(0xFF2563EB);
      iconData = LucideIcons.hourglass;
      badgeText = AssessmentTranslations.t('scalp_photos_under_review', language);
      title = AssessmentTranslations.t('clinical_review_in_progress', language);
      subtitle = '';
      description = AssessmentTranslations.t('photos_under_review_desc', language);
    } else {
      cardBg = const Color(0xFFFFFBEB);
      borderCol = const Color(0xFFFDE68A);
      iconCol = const Color(0xFFD97706);
      iconData = LucideIcons.clock;
      badgeText = AssessmentTranslations.t('assessment_submitted', language);
      title = AssessmentTranslations.t('assessment_ready', language);
      subtitle = '';
      description = state.aiAssessment == null ||
              !state.aiAssessment!.isAvailable ||
              state.aiAssessment!.requiresClinician
          ? AssessmentTranslations.t('clinician_review_needed_desc', language)
          : AssessmentTranslations.t('assessment_summary_ready_desc', language);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: Icon(iconData, color: iconCol, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderCol),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: iconCol,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildReviewTracker(),
        ],
      ),
    );
  }

  Widget _buildReviewTracker() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildTrackerStep(
            AssessmentTranslations.t('intake_sent', language),
            isDone: true,
            isActive: false,
            isLast: false,
          ),
          _buildTrackerStep(
            AssessmentTranslations.t('doctor_review', language),
            isDone: isReviewed,
            isActive: isUnderReview || !isReviewed,
            isLast: false,
          ),
          _buildTrackerStep(
            AssessmentTranslations.t('regimen_prescribed', language),
            isDone: isReviewed,
            isActive: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerStep(
    String label, {
    required bool isDone,
    required bool isActive,
    required bool isLast,
  }) {
    Color circleColor = const Color(0xFFE2E8F0);
    Color textColor = const Color(0xFF94A3B8);
    IconData icon = LucideIcons.circle;

    if (isDone) {
      circleColor = const Color(0xFF16A34A);
      textColor = const Color(0xFF166534);
      icon = LucideIcons.check;
    } else if (isActive) {
      circleColor = const Color(0xFF2563EB);
      textColor = const Color(0xFF1E40AF);
      icon = LucideIcons.clock;
    }

    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isDone || isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.only(bottom: 14),
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            ),
        ],
      ),
    );
  }
}
