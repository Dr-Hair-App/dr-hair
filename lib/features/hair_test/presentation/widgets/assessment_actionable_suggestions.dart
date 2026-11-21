import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';
import '../../../care/domain/models/care_models.dart';
import '../../../care/presentation/viewmodels/care_cubit.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_cubit.dart';
import '../viewmodels/hair_test_state.dart';

/// Comprehensive Actionable Suggestions, AI Routine & Diet Generation ('Auto List')
/// component rendered inside the Hair Assessment Report.
class AssessmentActionableSuggestionsCard extends StatefulWidget {
  final HairTestState state;
  final AiAssessmentModel aiAssessment;
  final AssessmentLanguage language;

  const AssessmentActionableSuggestionsCard({
    super.key,
    required this.state,
    required this.aiAssessment,
    this.language = AssessmentLanguage.english,
  });

  @override
  State<AssessmentActionableSuggestionsCard> createState() =>
      _AssessmentActionableSuggestionsCardState();
}

class _AssessmentActionableSuggestionsCardState
    extends State<AssessmentActionableSuggestionsCard> {
  bool _isAutoListing = false;
  bool _hasAddedToRoutine = false;

  bool get _isCritical =>
      widget.aiAssessment.isCritical ||
      widget.aiAssessment.scalpHealthScore < 50 ||
      widget.aiAssessment.requiresClinician ||
      widget.aiAssessment.stageClassification.toLowerCase().contains('stage 4') ||
      widget.aiAssessment.stageClassification.toLowerCase().contains('stage 5') ||
      widget.aiAssessment.stageClassification.toLowerCase().contains('patchy');

  String get _scalpWashCadence {
    final condition = widget.state.primaryConcern?.toLowerCase() ?? '';
    final summary = widget.aiAssessment.summary.toLowerCase();
    if (condition.contains('dandruff') ||
        summary.contains('dandruff') ||
        summary.contains('sebum') ||
        condition.contains('oily')) {
      return '3x Weekly (Mon / Wed / Sat) with clarifying anti-fungal / zinc cleanser. Lukewarm water only.';
    } else if (condition.contains('dry') || summary.contains('dry')) {
      return '2x Weekly (Tue / Sat) with ultra-gentle, sulfate-free nourishing cleanser to preserve scalp lipids.';
    }
    return '3x Weekly alternate-day wash. Avoid scalding hot water; finish with cool rinse.';
  }

  String get _scalpCareAdvice {
    final causes = widget.aiAssessment.rootCauses;
    for (final cause in causes) {
      final f = cause.factor.toLowerCase();
      if (f.contains('dht') || f.contains('follicle')) {
        return 'Apply targeted DHT-inhibiting topicals onto clean scalp. Leave on without immediate rinse.';
      }
      if (f.contains('stress') || f.contains('sleep')) {
        return 'Focus on evening scalp relaxation; nighttime cortisol spikes impair dermal papilla recovery.';
      }
      if (f.contains('nutrition') || f.contains('vitamin')) {
        return 'Ensure consistent micro-nutrient absorption alongside daily topical stimulation.';
      }
    }
    return 'Maintain balanced scalp hygiene, avoid friction from tight headwear, and protect scalp from UV exposure.';
  }

  List<RoutineTask> _buildPersonalizedTasks() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<RoutineTask> tasks = [];

    // 1. Regimen steps from assessment if available
    final dailySteps = widget.aiAssessment.recommendedRegimen.dailySteps;
    if (dailySteps.isNotEmpty) {
      for (int i = 0; i < dailySteps.length; i++) {
        final step = dailySteps[i];
        tasks.add(
          RoutineTask(
            id: 'auto_task_${now}_step_$i',
            title: step.step.isNotEmpty ? step.step : 'Regimen Step ${i + 1}',
            subtitle: step.instruction,
            category: 'Clinical Care',
            timeOfDay: i == 0 ? 'Morning' : (i == dailySteps.length - 1 ? 'Night' : 'Midday'),
            createdBy: 'ai_assessment',
          ),
        );
      }
    }

    // 2. Wash cadence task
    tasks.add(
      RoutineTask(
        id: 'auto_task_${now}_wash',
        title: 'Scalp Wash & Clarification',
        subtitle: _scalpWashCadence,
        category: 'Scalp Hygiene',
        timeOfDay: 'Morning',
        createdBy: 'ai_assessment',
      ),
    );

    // 3. Daily inverted scalp massage
    tasks.add(
      RoutineTask(
        id: 'auto_task_${now}_massage',
        title: 'Dermal Papilla Scalp Massage',
        subtitle: '4-5 minutes circular fingertip massage (inverted technique) to stimulate microcirculation.',
        category: 'Scalp Stimulation',
        timeOfDay: 'Evening',
        createdBy: 'ai_assessment',
      ),
    );

    // 4. Night topical application
    tasks.add(
      RoutineTask(
        id: 'auto_task_${now}_night',
        title: 'Night Regimen Application',
        subtitle: _scalpCareAdvice,
        category: 'Night Recovery',
        timeOfDay: 'Night',
        createdBy: 'ai_assessment',
      ),
    );

    return tasks;
  }

  List<DietMeal> _buildPersonalizedDietMeals() {
    final dietPlan = widget.aiAssessment.dietPlan;
    final foodsToEat = dietPlan.foodsToEat.isNotEmpty
        ? dietPlan.foodsToEat.join(', ')
        : 'Eggs, Lentils, Paneer, Spinach, Pumpkin Seeds, Greek Yogurt';

    return [
      const DietMeal(
        type: 'Breakfast',
        name: 'Keratin Protein & Biotin Fuel',
        nutrients: '20g-25g Protein, Biotin, Zinc',
        benefit: 'Provides vital amino acids (cysteine & methionine) for active hair shaft synthesis.',
      ),
      DietMeal(
        type: 'Lunch',
        name: 'Iron & Follicle Oxygenation Plate',
        nutrients: 'Iron, Vitamin C, Leafy Greens',
        benefit: 'Optimizes ferritin levels for oxygen and nutrient delivery to hair roots ($foodsToEat).',
      ),
      const DietMeal(
        type: 'Evening Snack',
        name: 'Omega-3 & Anti-DHT Mineral Mix',
        nutrients: 'Pumpkin Seeds, Walnuts, Zinc',
        benefit: 'Natural zinc and phytosterols to help modulate 5-alpha reductase activity.',
      ),
      const DietMeal(
        type: 'Dinner & Hydration',
        name: 'Microbiome Gut-Scalp Bowl',
        nutrients: 'Probiotics, Antioxidants, 2.5L Water target',
        benefit: 'Calms systemic scalp inflammation and supports deep nighttime cellular repair.',
      ),
    ];
  }

  Future<void> _handleAutoListToRoutine() async {
    setState(() => _isAutoListing = true);
    HapticFeedback.mediumImpact();

    try {
      final careCubit = context.read<CareCubit?>();
      final hairTestCubit = context.read<HairTestCubit?>();

      // 1. Optionally trigger backend routine and diet generation if reference exists
      if (hairTestCubit != null &&
          (widget.state.referenceNo?.isNotEmpty == true)) {
        await Future.wait([
          hairTestCubit.generatePersonalizedRoutine(),
          hairTestCubit.generatePersonalizedDietPlan(),
        ]);
      }

      // 2. Persist personalized tasks and meals into CareCubit
      if (careCubit != null) {
        final tasks = _buildPersonalizedTasks();
        final meals = _buildPersonalizedDietMeals();

        await careCubit.applyAssessmentRegimen(
          routineTasks: tasks,
          dietMeals: meals,
          dietTitle: 'AI Personalized Nutrition & Hair Regimen',
        );
      }

      if (mounted) {
        setState(() {
          _hasAddedToRoutine = true;
          _isAutoListing = false;
        });

        AppToast.show(
          context,
          const SnackBar(
            content: Text(
              'Personalized Routine & Diet successfully added to your Daily Care plan!',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAutoListing = false);
        AppToast.show(
          context,
          const SnackBar(
            content: Text('Could not complete auto-list. Please try again.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _contactDoctorOnWhatsApp() async {
    final aiAssessment = widget.aiAssessment;
    final authUser = context.read<AuthCubit?>()?.state.user;
    final patientId = (widget.state.patientId?.trim().isNotEmpty == true)
        ? widget.state.patientId!.trim()
        : (aiAssessment.patientCode?.trim().isNotEmpty == true
            ? aiAssessment.patientCode!.trim()
            : (aiAssessment.patientId?.trim().isNotEmpty == true
                ? aiAssessment.patientId!.trim()
                : (authUser?.patientId.trim().isNotEmpty == true
                    ? authUser!.patientId.trim()
                    : (widget.state.referenceNo ?? 'Patient'))));
    final patientName = widget.state.name.trim().isNotEmpty
        ? widget.state.name.trim()
        : 'Patient';
    final stage = aiAssessment.stageClassification.isNotEmpty
        ? aiAssessment.stageClassification
        : (widget.state.stage ?? 'Initial');
    final score = aiAssessment.scalpHealthScore;
    final concern = widget.state.primaryConcern?.trim().isNotEmpty == true
        ? widget.state.primaryConcern!.trim()
        : 'Hair fall & scalp health';

    final success = await WhatsAppLauncher.launchAssessmentGuidance(
      patientName: patientName,
      patientId: patientId,
      referenceNo: widget.state.referenceNo ?? 'N/A',
      stage: stage,
      scalpScore: score,
      concern: concern,
      phoneNumber: '918058056789',
    );

    if (!success && mounted) {
      AppToast.show(
        context,
        const SnackBar(
          content: Text('Could not open WhatsApp. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.sparkles,
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
                      'Actionable Suggestions & AI Plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Targeted doctor care, daily regimen & nutrition roadmap',
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
          const SizedBox(height: 18),

          // 1. DOCTOR CONSULTATION RECOMMENDATION
          _buildDoctorConsultationSection(context),
          const SizedBox(height: 18),

          // 2. DAILY ROUTINE MODIFICATIONS
          _buildDailyRoutineSection(),
          const SizedBox(height: 18),

          // 3. DIET MODIFICATIONS
          _buildDietModificationsSection(),
          const SizedBox(height: 20),

          // 4. AUTO LIST / ADD TO ROUTINE CTA
          _buildAutoListCTA(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. DOCTOR CONSULTATION SECTION
  // ---------------------------------------------------------------------------
  Widget _buildDoctorConsultationSection(BuildContext context) {
    final isCritical = _isCritical;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCritical ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical ? LucideIcons.stethoscope : LucideIcons.messageCircle,
                size: 18,
                color: isCritical
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 8),
              Text(
                isCritical
                    ? 'Clinical Trichology Consultation (High Urgency)'
                    : 'Doctor Guidance & Clinical Review',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: isCritical
                      ? const Color(0xFF92400E)
                      : const Color(0xFF14532D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCritical
                ? 'Your scalp health score (${widget.aiAssessment.scalpHealthScore}/100) indicates significant thinning or acute follicle sensitivity. An in-person clinical exam is strongly advised before initiating treatment.'
                : 'Your hair thinning is manageable with targeted topical therapy and dietary correction. You can connect directly with our senior trichologist via WhatsApp for personalized guidance.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isCritical
                  ? const Color(0xFF78350F)
                  : const Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isCritical) ...[
                Expanded(
                  flex: 3,
                  child: AppButton(
                    height: 40,
                    text: 'Book In-Clinic Slot',
                    icon: const Icon(
                      LucideIcons.calendarCheck,
                      size: 16,
                      color: Colors.white,
                    ),
                    variant: AppButtonVariant.filled,
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => context.push(RouteNames.clinicAppointment),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    height: 40,
                    text: 'WhatsApp',
                    icon: const Icon(
                      LucideIcons.messageCircle,
                      size: 15,
                      color: Color(0xFF92400E),
                    ),
                    variant: AppButtonVariant.outlined,
                    foregroundColor: const Color(0xFF92400E),
                    borderColor: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: _contactDoctorOnWhatsApp,
                  ),
                ),
              ] else ...[
                Expanded(
                  flex: 3,
                  child: AppButton(
                    height: 40,
                    text: 'Connect on WhatsApp',
                    icon: const Icon(
                      LucideIcons.messageCircle,
                      size: 16,
                      color: Colors.white,
                    ),
                    variant: AppButtonVariant.filled,
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    onPressed: _contactDoctorOnWhatsApp,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    height: 40,
                    text: 'Clinic Visit',
                    icon: const Icon(
                      LucideIcons.calendar,
                      size: 15,
                      color: Color(0xFF166534),
                    ),
                    variant: AppButtonVariant.outlined,
                    foregroundColor: const Color(0xFF166534),
                    borderColor: const Color(0xFF16A34A),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => context.push(RouteNames.clinicAppointment),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. DAILY ROUTINE MODIFICATIONS
  // ---------------------------------------------------------------------------
  Widget _buildDailyRoutineSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.repeat, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Daily Routine Modifications',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Wash Cadence Row
          _buildRoutineItem(
            icon: LucideIcons.waves,
            title: 'Wash Cadence & Cleansing',
            description: _scalpWashCadence,
          ),
          const SizedBox(height: 10),

          // Scalp Care
          _buildRoutineItem(
            icon: LucideIcons.shieldCheck,
            title: 'Targeted Scalp Care',
            description: _scalpCareAdvice,
          ),
          const SizedBox(height: 10),

          // Massage
          _buildRoutineItem(
            icon: LucideIcons.sparkles,
            title: 'Dermal Papilla Massage',
            description:
                'Spend 4-5 minutes daily performing inverted circular fingertip massage to boost follicular blood supply.',
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. DIET MODIFICATIONS
  // ---------------------------------------------------------------------------
  Widget _buildDietModificationsSection() {
    final diet = widget.aiAssessment.dietPlan;
    final hydration = diet.hydrationTarget.isNotEmpty
        ? diet.hydrationTarget
        : '2.5L - 3.0L daily';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.apple, size: 16, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text(
                'Dietary & Nutritional Modifications',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Protein Targets
          _buildDietItem(
            badge: 'PROTEIN TARGET',
            title: '50g - 65g Daily (Keratin Foundation)',
            subtitle:
                'Incorporate paneer, boiled eggs, lentils/dal, sprouts, and Greek yogurt to fuel active follicle cells.',
            badgeColor: const Color(0xFF059669),
          ),
          const SizedBox(height: 10),

          // Biotin & Micronutrients
          _buildDietItem(
            badge: 'BIOTIN & ZINC',
            title: 'Micronutrient Density',
            subtitle:
                '1 handful of raw pumpkin seeds + walnuts daily for bioavailable zinc and natural DHT suppression.',
            badgeColor: const Color(0xFFD97706),
          ),
          const SizedBox(height: 10),

          // Gut Health & Hydration
          _buildDietItem(
            badge: 'GUT & HYDRATION',
            title: 'Microbiome Support ($hydration)',
            subtitle:
                'Probiotic yogurt / kefir supports gut-hair axis integrity and lowers systemic follicle inflammation.',
            badgeColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _buildDietItem({
    required String badge,
    required String title,
    required String subtitle,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: badgeColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. AUTO LIST / ADD TO ROUTINE CTA
  // ---------------------------------------------------------------------------
  Widget _buildAutoListCTA(BuildContext context) {
    if (_hasAddedToRoutine) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.checkCircle2, color: Color(0xFF059669), size: 18),
                SizedBox(width: 8),
                Text(
                  'Added to Today\'s Routine & Diet Plan!',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    height: 40,
                    text: 'Open Routine',
                    variant: AppButtonVariant.outlined,
                    foregroundColor: const Color(0xFF065F46),
                    borderColor: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => context.push(RouteNames.routine),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    height: 40,
                    text: 'Open Diet Plan',
                    variant: AppButtonVariant.outlined,
                    foregroundColor: const Color(0xFF065F46),
                    borderColor: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: () => context.push(RouteNames.dietPlan),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        AppButton(
          height: 48,
          text: _isAutoListing
              ? 'Generating Routine & Meals...'
              : 'Auto List / Add to My Routine',
          variant: AppButtonVariant.filled,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: _isAutoListing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
          onPressed: _isAutoListing ? null : _handleAutoListToRoutine,
        ),
        const SizedBox(height: 6),
        const Text(
          'Generates personalized routine tasks & diet steps into your daily tracker in 1-tap.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
