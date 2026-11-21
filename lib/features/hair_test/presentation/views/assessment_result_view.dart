import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/app_button.dart';
import '../viewmodels/hair_test_cubit.dart';
import '../viewmodels/hair_test_state.dart';
import '../../domain/models/ai_assessment_model.dart';
import 'assessment_report_view.dart';

/// Standalone screen dedicated to viewing the Clinical Hair Assessment Result.
/// Accessible from Profile ("Assessment result") and direct navigation.
class AssessmentResultView extends StatelessWidget {
  final HairTestCubit? cubit;
  final String? referenceNo;

  const AssessmentResultView({super.key, this.cubit, this.referenceNo});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _AssessmentResultContent(referenceNo: referenceNo),
      );
    }
    final existingCubit = context.read<HairTestCubit?>();
    if (existingCubit != null) {
      return _AssessmentResultContent(referenceNo: referenceNo);
    }
    return BlocProvider(
      create: (_) => HairTestCubit()..loadSavedState(),
      child: _AssessmentResultContent(referenceNo: referenceNo),
    );
  }
}

class _AssessmentResultContent extends StatefulWidget {
  final String? referenceNo;

  const _AssessmentResultContent({this.referenceNo});

  @override
  State<_AssessmentResultContent> createState() =>
      _AssessmentResultContentState();
}

class _AssessmentResultContentState extends State<_AssessmentResultContent> {
  bool _previewSample = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final hairCubit = context.read<HairTestCubit?>();
        if (widget.referenceNo != null && widget.referenceNo!.trim().isNotEmpty) {
          hairCubit?.loadAssessmentByReference(widget.referenceNo!.trim());
        }
        hairCubit?.refreshClinicalReports();
      }
    });
  }

  static const HairTestState _sampleReportState = HairTestState(
    isCompleted: true,
    name: 'Sahil',
    age: '23',
    stage: 'Stage 2 - Receding Hairline',
    dandruff: 'Severe Dandruff & Flakes',
    gutHealth: 'Occasional Gas & Acidity',
    stressLevel: 'Moderate Stress & Brain Fog',
    selectedGender: 'Male',
    duration: '6-12 Months',
    familyHistory: 'Maternal thinning',
    referenceNo: 'HT-2026-SAMPLE',
    aiAssessment: AiAssessmentModel(
      scalpHealthScore: 68,
      stageClassification: 'Norwood Stage 2 - Early Thinning',
      summary:
          'Clinical AI evaluation identifies active hair fall linked with frontotemporal recession, compounded by micro-inflammation and dietary nutrient gaps.',
      rootCauses: [
        AiRootCause(
          factor: 'DHT Sensitivity & Genetic Susceptibility',
          severity: 'Moderate',
          explanation:
              'Follicular sensitivity around the temples leads to progressive hair shaft thinning.',
        ),
        AiRootCause(
          factor: 'Scalp Microbiome & Sebum Imbalance',
          severity: 'High',
          explanation:
              'Sebum buildup and Malassezia yeast trigger dandruff and follicle collar irritation.',
        ),
        AiRootCause(
          factor: 'Nutritional & Protein Deficit',
          severity: 'Moderate',
          explanation:
              'Keratin matrix requires elevated bioavailable amino acids and trace zinc.',
        ),
      ],
      dietPlan: AiDietPlan(
        summary:
            'High-protein nutrition with zinc and iron to fuel keratin synthesis.',
        foodsToEat: [
          'Eggs, Paneer or Tofu (Quality protein for keratin)',
          'Spinach & Methi greens (Iron & Folate for oxygenation)',
          'Pumpkin seeds & Walnuts (Zinc & Omega-3)',
          'Amla & Citrus fruits (Vitamin C for iron uptake)',
        ],
        foodsToAvoid: [
          'Refined white sugar and sodas (Spikes systemic inflammation)',
          'Deep-fried oily snacks (Oxidizes scalp sebum)',
          'Excessive caffeine on an empty stomach',
        ],
        hydrationTarget: '2.5 to 3.0 Litres daily',
        keyNutrients: ['Biotin', 'Zinc', 'Iron', 'Omega-3', 'Vitamin D3'],
      ),
      lifestyleGuidance: AiLifestyleGuidance(
        summary:
            'Calm the nervous system and adhere to non-stripping scalp cleansing.',
        scalpCareTips: [
          'Wash scalp 2-3 times weekly with a sulphate-free clarifying cleanser.',
          'Rinse only with lukewarm or ambient water.',
          'Use a wide-toothed wooden comb gently on dry hair.',
        ],
        oilingRules: [
          'Do NOT leave heavy oil on the scalp overnight when dandruff is present.',
          'Apply lightweight herbal oil 45 minutes before showering only.',
        ],
        sleepAndStress: [
          'Target 7-8 hours of uninterrupted nocturnal sleep.',
          'Practice 10 minutes of deep belly breathing daily.',
        ],
      ),
      recommendedRegimen: AiRecommendedRegimen(
        summary:
            'A 3-step targeted daily routine combining root stimulation and internal nourishment.',
        dailySteps: [
          AiRegimenStep(
            step: 'Morning',
            instruction:
                'Apply 1ml Dr. Hair Follicle Activator Serum to temple areas.',
          ),
          AiRegimenStep(
            step: 'Afternoon',
            instruction:
                'Take 1 Dr. Hair Biotin & Multivitamin tablet after meal.',
          ),
          AiRegimenStep(
            step: 'Night',
            instruction:
                '2-minute gentle finger-tip scalp massage before sleep.',
          ),
        ],
        targetProducts: [
          AiTargetProduct(
            name: 'Dr. Hair Follicle Activator Serum',
            category: 'Serums',
            reason: 'Counters local DHT miniaturization and awakens follicles.',
          ),
          AiTargetProduct(
            name: 'Dr. Hair Anti-Dandruff Scalp Cleanser',
            category: 'Hair Care',
            reason: 'Removes sebum crust and Malassezia yeast.',
          ),
          AiTargetProduct(
            name: 'Dr. Hair Biotin & Keratin Booster',
            category: 'Supplements',
            reason: 'Provides essential amino acids and micronutrients.',
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HairTestCubit, HairTestState>(
      builder: (context, state) {
        final hasRef = widget.referenceNo != null &&
            widget.referenceNo!.trim().isNotEmpty;
        final bool hasReport =
            state.isCompleted ||
            state.isSubmitted ||
            state.clinicalReports.isNotEmpty ||
            hasRef;

        if (hasReport) {
          final effectiveState = (hasRef &&
                  state.referenceNo != widget.referenceNo!.trim())
              ? state.copyWith(
                  referenceNo: widget.referenceNo!.trim(),
                  isCompleted: true,
                )
              : state;
          return AssessmentReportView(state: effectiveState);
        }

        if (_previewSample) {
          return AssessmentReportView(state: _sampleReportState);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                LucideIcons.arrowLeft,
                color: AppColors.primaryDark,
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(RouteNames.profile);
                }
              },
            ),
            centerTitle: true,
            title: const Text(
              'Assessment Result',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: AppColors.primary5,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.clipboardCheck,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'No Assessment Result Yet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Complete your hair assessment to review your answers and explore care options.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryDark,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Take Hair Assessment',
                        variant: AppButtonVariant.filled,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        onPressed: () => context.push(RouteNames.hairTest),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        height: 50,
                        text: 'Preview Sample Report',
                        variant: AppButtonVariant.outlined,
                        borderColor: AppColors.border,
                        foregroundColor: AppColors.primary,
                        onPressed: () {
                          setState(() {
                            _previewSample = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
