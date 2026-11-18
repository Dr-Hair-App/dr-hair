import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../localization/assessment_translations.dart';

/// Renders the verified doctor's customized care plan and prescribed medications.
class DoctorClinicalCarePlanCard extends StatelessWidget {
  final Map<String, dynamic> carePlan;
  final AssessmentLanguage language;

  const DoctorClinicalCarePlanCard({
    super.key,
    required this.carePlan,
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
    final String instructions =
        carePlan['instructions']?.toString() ??
        'Follow daily application schedule as directed.';
    final String? nextReview = carePlan['next_review_date']?.toString();
    final List medications = (carePlan['medications'] as List?) ?? [];
    final reviewer = _reviewerName(carePlan);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.pill,
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
                      AssessmentTranslations.t('clinical_care_plan', language),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    if (reviewer != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Prepared by $reviewer',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            AssessmentTranslations.t('regimen_instructions', language),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            instructions,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: Color(0xFF14532D),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (medications.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              AssessmentTranslations.t('prescribed_formulations', language),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF166534),
              ),
            ),
            const SizedBox(height: 8),
            for (final med in medications) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDCFCE7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.check,
                      size: 14,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        med['name']?.toString() ?? 'Medication',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                    if (med['dosage'] != null)
                      Text(
                        med['dosage'].toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
          if (nextReview != null && nextReview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  LucideIcons.calendar,
                  size: 14,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 6),
                Text(
                  '${AssessmentTranslations.t('next_clinical_review', language)}: $nextReview',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
