import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../domain/models/ai_assessment_model.dart';

/// AI screening summary, possible factors, nutrition, lifestyle, and daily routine.
class AiAssessmentCards extends StatefulWidget {
  final AiAssessmentModel aiAssessment;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final Future<void> Function()? onGenerateDietPlan;
  final bool isGeneratingDietPlan;
  final String? dietPlanError;
  final String? assessmentReferenceNo;

  const AiAssessmentCards({
    super.key,
    required this.aiAssessment,
    this.onRefresh,
    this.isRefreshing = false,
    this.onGenerateDietPlan,
    this.isGeneratingDietPlan = false,
    this.dietPlanError,
    this.assessmentReferenceNo,
  });

  @override
  State<AiAssessmentCards> createState() => _AiAssessmentCardsState();
}

class _AiAssessmentCardsState extends State<AiAssessmentCards> {
  int _selectedTab =
      0; // 0: Possible factors, 1: Diet Plan, 2: Lifestyle, 3: Daily Regimen

  @override
  void didUpdateWidget(covariant AiAssessmentCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aiAssessment.nextStepType == 'doctor_appointment') {
      _selectedTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.aiAssessment;
    if (!ai.isAvailable) return _buildUnavailableCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. AI Health Score & Clinical Summary Card
        _buildScoreAndSummaryCard(ai),

        const SizedBox(height: 16),

        // 2. Interactive Navigation Tabs
        _buildNavigationTabs(ai),

        const SizedBox(height: 16),

        // 3. Tab Content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildActiveTabContent(ai),
        ),
      ],
    );
  }

  Widget _buildUnavailableCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.info, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text(
                'AI assessment unavailable',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'We couldn’t prepare a reliable result, so no AI score, stage, or product recommendation is shown. You can retry or ask a clinician to review your answers.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF475569),
            ),
          ),
          if (widget.onRefresh != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.isRefreshing ? null : widget.onRefresh,
                icon: widget.isRefreshing
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.refreshCw, size: 15),
                label: Text(widget.isRefreshing ? 'Retrying…' : 'Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreAndSummaryCard(AiAssessmentModel ai) {
    final score = ai.scalpHealthScore.clamp(0, 100);
    // Emerald Green
    if (score < 50) {
      // Red
    } else if (score < 75) {
      // Amber
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.sparkles, color: Colors.white, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'Dr. Hair Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Screening result',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.info, size: 15, color: AppColors.primary),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Questionnaire-based guidance only · Not a diagnosis',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (ai.summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDF2F7)),
              ),
              child: Text(
                ai.summary,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(AiAssessmentModel ai) {
    final tabs = <({int id, String title, IconData icon})>[
      (id: 0, title: 'Possible factors', icon: LucideIcons.activity),
      if (ai.nextStepType != 'doctor_appointment')
        (id: 1, title: 'Diet Plan', icon: LucideIcons.utensils),
      if (ai.nextStepType != 'doctor_appointment') ...[
        (id: 2, title: 'Lifestyle', icon: LucideIcons.shieldCheck),
        (id: 3, title: 'Regimen', icon: LucideIcons.clock),
      ],
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _selectedTab == tab.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedTab = tab.id),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveTabContent(AiAssessmentModel ai) {
    if (_selectedTab != 0 && ai.nextStepType == 'doctor_appointment') {
      return _buildRootCausesTab(ai.rootCauses);
    }
    switch (_selectedTab) {
      case 0:
        return _buildRootCausesTab(ai.rootCauses);
      case 1:
        return _buildDietPlanTab(ai);
      case 2:
        return _buildLifestyleTab(ai.lifestyleGuidance);
      case 3:
      default:
        return _buildRegimenTab(ai.recommendedRegimen);
    }
  }

  Widget _buildRootCausesTab(List<AiRootCause> rootCauses) {
    if (rootCauses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No possible contributors were identified from these answers.',
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('root_causes_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Possible contributors based on your answers. These are not confirmed causes; ask a clinician if you are unsure.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        ...rootCauses.map(
          (cause) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cause.factor,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cause.explanation,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDietPlanTab(AiAssessmentModel ai) {
    final diet = ai.dietPlan;
    final customPlan = ai.customMealPlan;
    final days = customPlan?['days'] is List
        ? (customPlan!['days'] as List).whereType<Map>().toList()
        : const <Map>[];
    return Container(
      key: const ValueKey('diet_plan_tab'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (diet.summary.isNotEmpty) ...[
            Text(
              diet.summary,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Hydration & Key Nutrients
          if (diet.hydrationTarget.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.droplets,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Hydration Target',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        Text(
                          diet.hydrationTarget,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (diet.keyNutrients.isNotEmpty) ...[
            const Text(
              'Essential Hair Nutrients',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: diet.keyNutrients.map((nutrient) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    nutrient,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // Foods to Eat
          const Row(
            children: [
              Icon(LucideIcons.check, color: Color(0xFF059669), size: 16),
              SizedBox(width: 6),
              Text(
                'Foods to Eat (Follicle Nourishers)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...diet.foodsToEat.map(
            (food) => _buildBulletItem(
              text: food,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
          ),

          const SizedBox(height: 16),

          // Foods to Avoid
          const Row(
            children: [
              Icon(LucideIcons.alertCircle, color: Color(0xFFDC2626), size: 16),
              SizedBox(width: 6),
              Text(
                'Foods to Avoid (Inflammation Triggers)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...diet.foodsToAvoid.map(
            (food) => _buildBulletItem(
              text: food,
              iconColor: const Color(0xFFEF4444),
              bgColor: const Color(0xFFFEF2F2),
            ),
          ),
          const SizedBox(height: 18),
          if (customPlan != null && days.isNotEmpty) ...[
            _buildGeneratedMealPlan(context, customPlan, days),
            const SizedBox(height: 12),
          ],
          if (widget.dietPlanError != null) ...[
            Text(
              widget.dietPlanError!,
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          if (widget.onGenerateDietPlan != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.isGeneratingDietPlan
                    ? null
                    : widget.onGenerateDietPlan,
                icon: widget.isGeneratingDietPlan
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.sparkles, size: 16),
                label: Text(
                  widget.isGeneratingDietPlan
                      ? 'Creating your meal plan…'
                      : customPlan == null
                      ? 'Create a 7-day meal plan with Assistant'
                      : 'Create a new 7-day meal plan',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGeneratedMealPlan(
    BuildContext context,
    Map<String, dynamic> plan,
    List<Map> days,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your 7-day meal plan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF115E59),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'General nutrition guidance · not a diagnosis or treatment plan',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
          ),
          if ((plan['summary']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              plan['summary'].toString(),
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF334155),
              ),
            ),
          ],
          const SizedBox(height: 10),
          for (final day in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    day['day']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  for (final meal
                      in (day['meals'] is List
                          ? day['meals'] as List
                          : const []))
                    if (meal is Map)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '${meal['type'] ?? 'Meal'} · ${meal['name'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          if ((plan['safety_note']?.toString() ?? '').isNotEmpty)
            Text(
              plan['safety_note'].toString(),
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: Color(0xFF64748B),
              ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => context.push(
              RouteNames.contact,
              extra:
                  'I would like a clinician to review my AI meal plan because it may not be suitable for me. Assessment reference: ${widget.assessmentReferenceNo ?? 'not available'}.',
            ),
            icon: const Icon(LucideIcons.flag, size: 15),
            label: const Text('Report a plan that seems unsuitable'),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleTab(AiLifestyleGuidance lifestyle) {
    return Container(
      key: const ValueKey('lifestyle_tab'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lifestyle.summary.isNotEmpty) ...[
            Text(
              lifestyle.summary,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Scalp Care Tips
          if (lifestyle.scalpCareTips.isNotEmpty) ...[
            const Row(
              children: [
                Icon(LucideIcons.sparkles, color: AppColors.primary, size: 16),
                SizedBox(width: 6),
                Text(
                  'Scalp Hygiene & Washing',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lifestyle.scalpCareTips.map(
              (tip) => _buildBulletItem(
                text: tip,
                iconColor: AppColors.primary,
                bgColor: const Color(0xFFF0FDFA),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Oiling Rules
          if (lifestyle.oilingRules.isNotEmpty) ...[
            const Row(
              children: [
                Icon(LucideIcons.droplets, color: Color(0xFFD97706), size: 16),
                SizedBox(width: 6),
                Text(
                  'Trichology Oiling Guidelines',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lifestyle.oilingRules.map(
              (rule) => _buildBulletItem(
                text: rule,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Sleep & Stress
          if (lifestyle.sleepAndStress.isNotEmpty) ...[
            const Row(
              children: [
                Icon(LucideIcons.moon, color: Color(0xFF6366F1), size: 16),
                SizedBox(width: 6),
                Text(
                  'Restorative Sleep & Cortisol Management',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4338CA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lifestyle.sleepAndStress.map(
              (item) => _buildBulletItem(
                text: item,
                iconColor: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegimenTab(AiRecommendedRegimen regimen) {
    return Column(
      key: const ValueKey('regimen_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Steps Timeline
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    LucideIcons.calendarCheck2,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Daily care starter plan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...regimen.dailySteps.map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          step.step,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.instruction,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem({
    required String text,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(LucideIcons.check, size: 10, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
