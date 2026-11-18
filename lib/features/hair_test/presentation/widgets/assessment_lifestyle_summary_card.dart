import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_state.dart';

/// Renders the patient's submitted demographic and lifestyle facts ("WHAT YOU SHARED")
/// along with the medical guidance and usage disclaimer.
class AssessmentLifestyleSummaryCard extends StatelessWidget {
  final HairTestState state;
  final AssessmentLanguage language;

  const AssessmentLifestyleSummaryCard({
    super.key,
    required this.state,
    this.language = AssessmentLanguage.english,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      (
        key: AssessmentTranslations.t('gender', language),
        value: state.selectedGender ?? 'Not selected',
      ),
      (
        key: AssessmentTranslations.t('age', language),
        value: state.age.isNotEmpty ? state.age : 'Not specified',
      ),
      if (state.primaryConcern != null && state.primaryConcern!.isNotEmpty)
        (
          key: AssessmentTranslations.t('main_concern', language),
          value: state.primaryConcern!,
        ),
      if (state.duration != null && state.duration!.isNotEmpty)
        (
          key: AssessmentTranslations.t('duration', language),
          value: state.duration!,
        ),
      if (state.dandruff != null && state.dandruff!.isNotEmpty)
        (
          key: AssessmentTranslations.t('dandruff_status', language),
          value: state.dandruff!,
        ),
      if (state.familyHistory != null && state.familyHistory!.isNotEmpty)
        (
          key: AssessmentTranslations.t('family_history', language),
          value: state.familyHistory!,
        ),
      if (state.gutHealth != null && state.gutHealth!.isNotEmpty)
        (
          key: AssessmentTranslations.t('gut_health', language),
          value: state.gutHealth!,
        ),
      if (state.stressLevel != null && state.stressLevel!.isNotEmpty)
        (
          key: AssessmentTranslations.t('stress_level', language),
          value: state.stressLevel!,
        ),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AssessmentTranslations.t('what_you_shared', language),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AssessmentTranslations.t('what_you_shared_desc', language),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.secondaryDark,
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < details.length; index++) ...[
                if (index > 0)
                  const Divider(height: 16, color: AppColors.border),
                _buildSummaryRow(details[index].key, details[index].value),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.stethoscope,
                color: Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AssessmentTranslations.t('how_to_use_result', language),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AssessmentTranslations.t('disclaimer_desc', language),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.secondaryDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
