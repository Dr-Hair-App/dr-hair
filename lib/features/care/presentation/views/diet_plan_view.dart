import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/care_models.dart';
import '../viewmodels/care_cubit.dart';
import '../viewmodels/care_state.dart';
import '../widgets/care_widgets.dart';

/// 4. Diet & Nutrition Guide View
/// Tailored trichological nutrition plans, daily meal checklists, and hydration tracking.
class DietPlanView extends StatelessWidget {
  const DietPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CareCubit, CareState>(
      builder: (context, state) {
        final currentDay = state.currentDietDay;
        final currentDayMeals = currentDay < state.dietPlans.length
            ? state.dietPlans[currentDay]
            : <DietMeal>[];

        final hasPlans = state.dietPlans.isNotEmpty;

        const dayTitles = [
          'Day 1: High Protein',
          'Day 2: Zinc & Folate',
          'Day 3: Iron & Omega-3',
        ];

        return CarePageScaffold(
          title: 'Nutrition & Diet Guide',
          isScrollable: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => context.read<CareCubit>().fetchPatientDietPlan(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(top: 16, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Cards & Section Header with natural 16px page padding
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasPlans)
                          careCard(
                            backgroundColor: const Color(0xFFFFF7ED),
                            border: Border.all(color: const Color(0xFFFFEDD5)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.dietTreatmentName.isNotEmpty
                                      ? state.dietTreatmentName
                                      : 'Your nutrition plan',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF9A3412),
                                  ),
                                ),
                                if (state.dietDoctorName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Added by ${state.dietDoctorName}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF7C2D12),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        // Interactive Water Intake Tracker
                        careCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF0F9FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          LucideIcons.droplets,
                                          color: Color(0xFF0284C7),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Scalp Hydration Tracker',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '${state.waterCups}/8 glasses (${state.waterCups * 300} ml)',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.secondaryDark,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.minusCircle,
                                        ),
                                        color: AppColors.primary,
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          context
                                              .read<CareCubit>()
                                              .decrementWater();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          LucideIcons.plusCircle,
                                        ),
                                        color: AppColors.primary,
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          context
                                              .read<CareCubit>()
                                              .incrementWater();
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 8-Glass Tap-to-Log Grid
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final itemWidth = (constraints.maxWidth - 28) / 8;
                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(8, (index) {
                                      final glassNumber = index + 1;
                                      final isFilled = state.waterCups >= glassNumber;
                                      return Semantics(
                                        label: 'Glass $glassNumber, 300 ml. ${isFilled ? 'Filled' : 'Empty'}',
                                        button: true,
                                        child: GestureDetector(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            final cubit = context.read<CareCubit>();
                                            if (state.waterCups == glassNumber) {
                                              cubit.setWater(glassNumber - 1);
                                            } else {
                                              cubit.setWater(glassNumber);
                                            }
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: itemWidth.clamp(28.0, 42.0),
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: isFilled
                                                  ? const Color(0xFF0284C7)
                                                  : const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isFilled
                                                    ? const Color(0xFF0284C7)
                                                    : const Color(0xFFCBD5E1),
                                                width: isFilled ? 1.5 : 1.0,
                                              ),
                                              boxShadow: isFilled
                                                  ? [
                                                      BoxShadow(
                                                        color: const Color(0xFF0284C7)
                                                            .withValues(alpha: 0.25),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  LucideIcons.droplet,
                                                  size: 16,
                                                  color: isFilled
                                                      ? Colors.white
                                                      : const Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  '$glassNumber',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isFilled
                                                        ? Colors.white
                                                        : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              // Hydration Clinical Insight
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: state.waterCups >= 8
                                      ? const Color(0xFFECFDF5)
                                      : const Color(0xFFF0F9FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      state.waterCups >= 8
                                          ? LucideIcons.circleCheck
                                          : LucideIcons.info,
                                      size: 13,
                                      color: state.waterCups >= 8
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF0284C7),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        state.waterCups >= 8
                                            ? 'Daily scalp hydration target achieved! Follicles nourished.'
                                            : 'Target 2.4L daily to optimize scalp micro-circulation and flush DHT.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: state.waterCups >= 8
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        careSectionHeader(
                          title: 'DAILY ROTATING MEAL PLAN',
                          subtitle: hasPlans
                              ? 'Tap each meal once completed'
                              : 'Personalized clinical nutrition',
                        ),
                      ],
                    ),
                  ),

                  if (state.assistantDietMeals.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: careCard(
                        backgroundColor: const Color(0xFFF0FDFA),
                        border: Border.all(color: const Color(0xFFCCFBF1)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.assistantDietTitle.isEmpty
                                  ? 'My meal plan'
                                  : state.assistantDietTitle,
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'AI-generated general nutrition ideas · not a prescribed diet',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...state.assistantDietMeals.map(
                              (meal) => Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      LucideIcons.circleCheck,
                                      size: 15,
                                      color: Color(0xFF0F766E),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${meal.type}: ${meal.name}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                          if (meal.benefit.isNotEmpty)
                                            Text(
                                              meal.benefit,
                                              style: const TextStyle(
                                                fontSize: 10.5,
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
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (state.isLoadingDiet)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (!hasPlans)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.salad,
                                size: 32,
                                color: Color(0xFF059669),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Custom Diet Plan Assigned Yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your trichologist will assess your hair condition during consultation and prescribe a customized nutrition plan here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryDark,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Day selector tabs (Edge-to-edge scroll with natural 16px start/end padding & 8px tab spacing)
                    CareHorizontalTabBar(
                      tabs: List.generate(
                        state.dietPlans.length,
                        (idx) => idx < dayTitles.length
                            ? dayTitles[idx]
                            : 'Day ${idx + 1}',
                      ),
                      selectedIndex: currentDay < state.dietPlans.length
                          ? currentDay
                          : 0,
                      onTabSelected: (idx) {
                        context.read<CareCubit>().selectDietDay(idx);
                      },
                    ),

                    const SizedBox(height: 14),

                    // Bottom Content with natural 16px page padding
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Meals list
                          ...currentDayMeals.asMap().entries.map((entry) {
                            final mealIdx = entry.key;
                            final meal = entry.value;
                            final isDone = meal.isCompleted;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFFFAFAFA)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDone
                                      ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.3)
                                      : AppColors.border,
                                  width: isDone ? 1.5 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.read<CareCubit>().toggleDietMeal(
                                    currentDay,
                                    mealIdx,
                                  );
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 24,
                                      height: 24,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDone
                                            ? const Color(0xFF10B981)
                                            : Colors.white,
                                        border: Border.all(
                                          color: isDone
                                              ? const Color(0xFF10B981)
                                              : AppColors.border,
                                          width: 2,
                                        ),
                                      ),
                                      child: isDone
                                          ? const Icon(
                                              LucideIcons.check,
                                              size: 14,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                meal.type.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFECFDF5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  meal.nutrients,
                                                  style: const TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF059669),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            meal.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDone
                                                  ? AppColors.textSecondary
                                                  : AppColors.primaryDark,
                                              decoration: isDone
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            meal.benefit,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.secondaryDark,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        careSectionHeader(title: 'HAIR SUPERFOODS GLOSSARY'),
                        careCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildSuperfoodRow(
                                icon: '🫐',
                                title: 'Amla & Berries',
                                desc: 'Highest natural Vitamin C; drives scalp collagen.',
                              ),
                              const Divider(height: 20),
                              _buildSuperfoodRow(
                                icon: '🎃',
                                title: 'Pumpkin Seeds',
                                desc: 'Rich in phytosterols & zinc to suppress DHT naturally.',
                              ),
                              const Divider(height: 20),
                              _buildSuperfoodRow(
                                icon: '🥬',
                                title: 'Spinach & Methi',
                                desc: 'Bioavailable non-heme iron to lift ferritin levels.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildSuperfoodRow({
    required String icon,
    required String title,
    required String desc,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.secondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
