import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_state.dart';

/// Clinical Assessment Overview Card displaying patient demographic details,
/// self-reported stage illustration, diagnosed severity, and primary concern.
class AssessmentOverviewCard extends StatelessWidget {
  final HairTestState state;
  final AssessmentLanguage language;

  const AssessmentOverviewCard({
    super.key,
    required this.state,
    this.language = AssessmentLanguage.english,
  });

  static ({String label, String asset})? selectedPatternIllustration(
    HairTestState state,
  ) {
    final selected = state.primaryConcern?.trim();
    final value = selected == null || selected.isEmpty
        ? state.stage?.trim()
        : selected;
    if (value == null || value.isEmpty || value == 'Not sure') return null;

    const stageAssets = <String, String>{
      'Stage 1': 'assets/images/hair_assessment/stage_1.png',
      'Stage 2': 'assets/images/hair_assessment/stage_2.png',
      'Stage 3': 'assets/images/hair_assessment/stage_3.png',
      'Stage 4': 'assets/images/hair_assessment/stage_4.png',
      'Stage 5': 'assets/images/hair_assessment/stage_5.png',
    };
    for (final entry in stageAssets.entries) {
      if (value == entry.key || value.startsWith('${entry.key} -')) {
        return (label: entry.key, asset: entry.value);
      }
    }

    final normalized = value.toLowerCase();
    if (normalized.contains('patch')) {
      return (
        label: 'Patchy hair loss',
        asset: 'assets/images/hair_assessment/patchy_loss.png',
      );
    }
    if (normalized.contains('shed') || normalized.contains('hair fall')) {
      return (
        label: 'Hair shedding',
        asset: 'assets/images/hair_assessment/hair_fall.png',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pattern = selectedPatternIllustration(state);
    final String trimmedName = state.name.trim();
    final String displayName = trimmedName.isNotEmpty
        ? '${trimmedName[0].toUpperCase()}${trimmedName.substring(1)}, ${state.age}'
        : 'Patient, ${state.age}';

    final localizedStageTitle = AssessmentTranslations.translateStage(
      state.stageTitle,
      language,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                AssessmentTranslations.t('assessment_overview', language),
                style: const TextStyle(
                  color: AppColors.secondaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              if (state.referenceNo != null && state.referenceNo!.isNotEmpty)
                Text(
                  state.referenceNo!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryDark,
                  ),
                ),
            ],
          ),
          if (pattern != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary5,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Image.asset(
                      pattern.asset,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AssessmentTranslations.t('selected_pattern', language),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pattern.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AssessmentTranslations.t(
                            'pattern_matches_reported',
                            language,
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: AppColors.secondaryDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizedStageTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  LucideIcons.clipboardCheck,
                  color: AppColors.primary,
                  size: 25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCFCE7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AssessmentTranslations.t('reported_concern', language),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.stageDescription,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
