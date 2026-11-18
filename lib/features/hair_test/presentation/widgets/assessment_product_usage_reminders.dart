import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../care/domain/models/care_models.dart';
import '../../../care/presentation/viewmodels/care_cubit.dart';
import '../../../shop/data/models/product_model.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../localization/assessment_translations.dart';
import 'assessment_reminder_dialog.dart';

/// Clinical instruction spec for hair care regimen products
class _ProductInstructionSpec {
  final String productName;
  final String category;
  final String treatmentType;
  final String dosage;
  final String timing;
  final TimeOfDay suggestedTime;
  final List<String> applicationSteps;
  final IconData icon;

  const _ProductInstructionSpec({
    required this.productName,
    required this.category,
    required this.treatmentType,
    required this.dosage,
    required this.timing,
    required this.suggestedTime,
    required this.applicationSteps,
    required this.icon,
  });
}

/// Product Usage Instructions & Reminders Widget for [AssessmentReportView].
/// Displays dosage, timing, step-by-step application directions, and customizable
/// notification reminders with live synchronization to [CareCubit].
class AssessmentProductUsageRemindersCard extends StatelessWidget {
  final AiAssessmentModel aiAssessment;
  final List<ProductItem> recommendedProducts;
  final AssessmentLanguage language;

  const AssessmentProductUsageRemindersCard({
    super.key,
    required this.aiAssessment,
    required this.recommendedProducts,
    this.language = AssessmentLanguage.english,
  });

  static const List<_ProductInstructionSpec> _fallbackRegimenSpecs = [
    _ProductInstructionSpec(
      productName: 'Dr. Hair Follicle Activator Serum',
      category: 'Topical Solution',
      treatmentType: 'Topical Serum',
      dosage: '1ml (1 full dropper)',
      timing: 'Night · 30 min before bed',
      suggestedTime: TimeOfDay(hour: 21, minute: 30),
      applicationSteps: [
        'Ensure scalp is clean and completely dry before applying.',
        'Part hair into 4 distinct quadrants along thinning areas.',
        'Dispense 1ml directly onto the scalp (not hair strands).',
        'Gently massage using fingertips in circular motions for 2 minutes.',
        'Leave on overnight; do not rinse or shampoo immediately.',
      ],
      icon: LucideIcons.droplets,
    ),
    _ProductInstructionSpec(
      productName: 'Biotin & DHT Defense Multi-Nutrient',
      category: 'Oral Nutrition',
      treatmentType: 'Oral Supplement',
      dosage: '1 tablet with water',
      timing: 'Morning · After breakfast',
      suggestedTime: TimeOfDay(hour: 8, minute: 30),
      applicationSteps: [
        'Take 1 tablet daily immediately following a protein-rich breakfast.',
        'Swallow whole with a full glass (250ml) of room-temperature water.',
        'Consistent daily timing promotes optimal bio-availability.',
      ],
      icon: LucideIcons.pill,
    ),
    _ProductInstructionSpec(
      productName: 'Anti-Dandruff & Clarifying Scalp Wash',
      category: 'Medicated Cleanser',
      treatmentType: 'Medicated Wash',
      dosage: '5-10ml (palm-sized coin)',
      timing: 'Morning · Alternate Days (3x/week)',
      suggestedTime: TimeOfDay(hour: 9, minute: 0),
      applicationSteps: [
        'Wet hair thoroughly with lukewarm (not hot) water.',
        'Lather 5-10ml between palms and apply directly to the scalp.',
        'Leave lather on scalp for 3 to 5 minutes to let active ketoconazole absorb.',
        'Rinse thoroughly and follow with a lightweight conditioner on hair ends.',
      ],
      icon: LucideIcons.waves,
    ),
  ];

  _ProductInstructionSpec _getSpecForProduct(ProductItem product) {
    final nameLower = product.name.toLowerCase();
    final catLower = product.category.toLowerCase();

    if (nameLower.contains('serum') ||
        catLower.contains('serum') ||
        nameLower.contains('solution') ||
        nameLower.contains('minoxidil')) {
      final steps = product.usageSteps.isNotEmpty
          ? product.usageSteps.map((s) => s.description.isNotEmpty ? s.description : s.title).toList()
          : const [
              'Part hair into sections across the crown and hairline.',
              'Apply 1ml dropper directly to scalp.',
              'Gently massage for 2 minutes with fingertips.',
              'Leave on overnight; do not rinse.',
            ];

      return _ProductInstructionSpec(
        productName: product.name,
        category: product.category,
        treatmentType: 'Topical Serum',
        dosage: '1ml dropper',
        timing: 'Night · 30 min before bed',
        suggestedTime: const TimeOfDay(hour: 21, minute: 30),
        applicationSteps: steps,
        icon: LucideIcons.droplets,
      );
    } else if (nameLower.contains('shampoo') ||
        catLower.contains('wash') ||
        nameLower.contains('cleanser')) {
      final steps = product.usageSteps.isNotEmpty
          ? product.usageSteps.map((s) => s.description.isNotEmpty ? s.description : s.title).toList()
          : const [
              'Wet hair thoroughly with lukewarm water.',
              'Work shampoo into scalp, creating a rich lather.',
              'Leave on for 3 minutes for botanical absorption.',
              'Rinse completely with cool water.',
            ];

      return _ProductInstructionSpec(
        productName: product.name,
        category: product.category,
        treatmentType: 'Medicated Wash',
        dosage: '5-10ml coin size',
        timing: 'Morning · Alternate Days',
        suggestedTime: const TimeOfDay(hour: 8, minute: 0),
        applicationSteps: steps,
        icon: LucideIcons.waves,
      );
    } else if (nameLower.contains('gummy') ||
        nameLower.contains('tablet') ||
        catLower.contains('supplement') ||
        catLower.contains('nutrition')) {
      final steps = product.usageSteps.isNotEmpty
          ? product.usageSteps.map((s) => s.description.isNotEmpty ? s.description : s.title).toList()
          : const [
              'Take 1 serving daily after a nutritious meal.',
              'Drink a full glass of water.',
              'Avoid taking on an empty stomach.',
            ];

      return _ProductInstructionSpec(
        productName: product.name,
        category: product.category,
        treatmentType: 'Oral Supplement',
        dosage: '1 tablet / gummy',
        timing: 'Morning · With breakfast',
        suggestedTime: const TimeOfDay(hour: 8, minute: 30),
        applicationSteps: steps,
        icon: LucideIcons.pill,
      );
    }

    return _ProductInstructionSpec(
      productName: product.name,
      category: product.category,
      treatmentType: 'Daily Care',
      dosage: 'As recommended',
      timing: 'Daily as prescribed',
      suggestedTime: const TimeOfDay(hour: 20, minute: 0),
      applicationSteps: product.usageSteps.isNotEmpty
          ? product.usageSteps.map((s) => s.description.isNotEmpty ? s.description : s.title).toList()
          : const [
              'Apply evenly across target scalp region.',
              'Massage gently until fully absorbed.',
            ],
      icon: LucideIcons.sparkles,
    );
  }

  CareReminder? _findExistingReminder(
    List<CareReminder> reminders,
    String productName,
  ) {
    final lowerName = productName.toLowerCase().trim();
    for (final rem in reminders) {
      if (rem.title.toLowerCase().contains(lowerName) ||
          lowerName.contains(rem.title.toLowerCase())) {
        return rem;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final careCubit = context.watch<CareCubit?>();
    final reminders = careCubit?.state.reminders ?? const <CareReminder>[];

    final List<_ProductInstructionSpec> specsToDisplay =
        recommendedProducts.isNotEmpty
            ? recommendedProducts.take(3).map(_getSpecForProduct).toList()
            : _fallbackRegimenSpecs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.alarmClock,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Product Usage & Reminders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Precise dosages, application instructions & custom alerts',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Product instruction cards
          ...specsToDisplay.map((spec) {
            final existingReminder = _findExistingReminder(reminders, spec.productName);
            return _buildProductInstructionTile(context, spec, existingReminder);
          }),
        ],
      ),
    );
  }

  Widget _buildProductInstructionTile(
    BuildContext context,
    _ProductInstructionSpec spec,
    CareReminder? existingReminder,
  ) {
    final bool hasActiveReminder = existingReminder != null && existingReminder.isEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveReminder
              ? AppColors.primary.withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, Category, Icon & Reminder Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(spec.icon, color: AppColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasActiveReminder) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        existingReminder.timeFormatted,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Badges: Timing & Dosage
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.clock, size: 12, color: AppColors.primaryDark),
                    const SizedBox(width: 5),
                    Text(
                      spec.timing,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.sparkles, size: 12, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Text(
                      spec.dosage,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Application Steps
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Application Steps:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                for (int i = 0; i < spec.applicationSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            spec.applicationSteps[i],
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Interactive Set / Edit Reminder Button
          InkWell(
            onTap: () => AssessmentReminderDialog.show(
              context,
              productName: spec.productName,
              treatmentType: spec.treatmentType,
              defaultDosage: spec.dosage,
              defaultTiming: spec.timing,
              initialTime: existingReminder?.time ?? spec.suggestedTime,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: hasActiveReminder
                    ? const Color(0xFFF1F5F9)
                    : AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasActiveReminder
                      ? const Color(0xFFCBD5E1)
                      : AppColors.primary200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasActiveReminder ? LucideIcons.bell : LucideIcons.bellPlus,
                    size: 14,
                    color: hasActiveReminder
                        ? AppColors.primaryDark
                        : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasActiveReminder
                        ? 'Modify Reminder (${existingReminder.timeFormatted})'
                        : 'Set Daily Reminder',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasActiveReminder
                          ? AppColors.primaryDark
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
