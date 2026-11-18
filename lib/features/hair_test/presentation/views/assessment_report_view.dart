import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';
import '../../../care/domain/models/care_models.dart';
import '../../../care/presentation/viewmodels/care_cubit.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../shop/presentation/viewmodels/cart_cubit.dart';
import '../../data/services/assessment_pdf_generator.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_cubit.dart';
import '../viewmodels/hair_test_state.dart';
import '../widgets/ai_analysis_loading_overlay.dart';
import '../widgets/ai_assessment_cards.dart';
import '../widgets/assessment_actionable_suggestions.dart';
import '../widgets/assessment_language_sheet.dart';
import '../widgets/assessment_lifestyle_summary_card.dart';
import '../widgets/assessment_overview_card.dart';
import '../widgets/assessment_product_usage_reminders.dart';
import '../widgets/assessment_recommendation_card.dart';
import '../widgets/doctor_clinical_care_plan_card.dart';
import '../widgets/doctor_clinical_documents_card.dart';
import '../widgets/doctor_consultation_action_card.dart';
import '../widgets/expert_review_notice_card.dart';
import '../widgets/scalp_photos_gallery_card.dart';

/// The Clinical Assessment Report View displaying the patient's hair test diagnosis,
/// verified doctor reports, uploaded scalp photos, personalized recommended products,
/// in-clinic doctor consultation options, and dynamic multilingual translation.
class AssessmentReportView extends StatefulWidget {
  final HairTestState state;

  const AssessmentReportView({super.key, required this.state});

  @override
  State<AssessmentReportView> createState() => _AssessmentReportViewState();
}

class _AssessmentReportViewState extends State<AssessmentReportView> {
  late bool _isRequestingAi;
  bool _isAddingRoutine = false;
  AssessmentLanguage _currentLanguage = AssessmentLanguage.english;

  @override
  void initState() {
    super.initState();
    _isRequestingAi =
        widget.state.aiAssessment == null &&
        widget.state.referenceNo?.isNotEmpty == true &&
        widget.state.aiAssessmentStatus != 'failed';
    if (_isRequestingAi) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final cubit = context.read<HairTestCubit?>();
        if (cubit != null && cubit.state.aiAssessment == null) {
          await cubit.fetchAiAssessment();
        }
        if (mounted) setState(() => _isRequestingAi = false);
      });
    }
  }

  Future<void> _retryAiAssessment() async {
    if (_isRequestingAi) return;
    setState(() => _isRequestingAi = true);
    try {
      await context.read<HairTestCubit?>()?.fetchAiAssessment(
        forceRefresh: true,
      );
    } finally {
      if (mounted) setState(() => _isRequestingAi = false);
    }
  }

  Future<void> _contactDoctorOnWhatsApp([HairTestState? stateOverride]) async {
    final state = stateOverride ?? widget.state;
    final aiAssessment = state.aiAssessment;
    final authUser = context.read<AuthCubit?>()?.state.user;
    final patientId = (state.patientId?.trim().isNotEmpty == true)
        ? state.patientId!.trim()
        : (aiAssessment?.patientCode?.trim().isNotEmpty == true
              ? aiAssessment!.patientCode!.trim()
              : (aiAssessment?.patientId?.trim().isNotEmpty == true
                    ? aiAssessment!.patientId!.trim()
                    : (authUser?.patientId.trim().isNotEmpty == true
                          ? authUser!.patientId.trim()
                          : (state.referenceNo ?? 'Patient'))));
    final patientName = state.name.trim().isNotEmpty
        ? state.name.trim()
        : 'Patient';
    final stage = aiAssessment?.stageClassification.isNotEmpty == true
        ? aiAssessment!.stageClassification
        : (state.stage ?? 'Initial');
    final score = aiAssessment?.scalpHealthScore ?? 70;
    final concern = state.primaryConcern?.trim().isNotEmpty == true
        ? state.primaryConcern!.trim()
        : 'Hair fall & scalp health';

    final success = await WhatsAppLauncher.launchAssessmentGuidance(
      patientName: patientName,
      patientId: patientId,
      referenceNo: state.referenceNo ?? 'N/A',
      stage: stage,
      scalpScore: score,
      concern: concern,
      phoneNumber: '918058056789',
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp. Please try again.'),
        ),
      );
    }
  }

  Future<void> _saveAssessmentRoutine(
    BuildContext context,
    List<AiRegimenStep> routineSteps,
  ) async {
    if (routineSteps.isEmpty) {
      context.push(RouteNames.routine);
      return;
    }
    final careCubit = context.read<CareCubit?>();
    if (careCubit == null) {
      context.push(RouteNames.routine);
      return;
    }

    setState(() => _isAddingRoutine = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tasks = routineSteps.map((step) => RoutineTask(
        id: 'assessment_plan_${now}_${step.step.replaceAll(' ', '_')}',
        title: 'Assessment plan · ${step.step}',
        subtitle: step.instruction,
        category: 'Daily care',
        timeOfDay: step.step,
        createdBy: 'ai_assessment',
      )).toList();
      await careCubit.addMultipleRoutineTasks(tasks);
    } finally {
      if (mounted) setState(() => _isAddingRoutine = false);
    }
    if (!context.mounted) return;
    context.push(RouteNames.routine);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HairTestCubit, HairTestState>(
      builder: (context, dynamicState) {
        final state = dynamicState.isCompleted || dynamicState.isSubmitted
            ? dynamicState
            : widget.state;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final horizontalPadding = (screenWidth * 0.045)
            .clamp(16.0, 28.0)
            .toDouble();

        if ((_isRequestingAi || state.isSubmitting) &&
            state.aiAssessment == null) {
          return const AiAnalysisLoadingOverlay();
        }

        final aiAssessment = state.aiAssessment;
        final recommendedProducts =
            aiAssessment?.availableProducts
                .map(ProductItem.fromJson)
                .toList() ??
            const <ProductItem>[];

        final isReviewed =
            state.assessmentStatus == 'reviewed' ||
            state.doctorCarePlan != null;
        final isUnderReview = state.assessmentStatus == 'under_review';
        final aiUnavailable = aiAssessment == null || !aiAssessment.isAvailable;
        final bool isCritical =
            !aiUnavailable &&
            (aiAssessment.isCritical ||
                state.aiAssessment?.nextStepType == 'doctor_appointment');
        final bool aiRecommendsDoctor =
            isCritical ||
            state.aiAssessment?.nextStepType == 'doctor_appointment';
        final List<AiRegimenStep> careRoutineSteps =
            state.aiAssessment?.isAvailable == true
                ? state.aiAssessment!.recommendedRegimen.dailySteps
                : const <AiRegimenStep>[];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(
                LucideIcons.arrowLeft,
                color: AppColors.primaryDark,
              ),
              onPressed: () {
                context.read<HairTestCubit>().dismissReport();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(RouteNames.mainShell);
                }
              },
            ),
            title: Text(
              AssessmentTranslations.t(
                'assessment_report_title',
                _currentLanguage,
              ),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            actions: [
              // Multilingual Selector Icon Button
              IconButton(
                tooltip: 'Language / भाषा (${_currentLanguage.displayName})',
                icon: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary5,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.languages,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentLanguage == AssessmentLanguage.english
                            ? 'EN'
                            : (_currentLanguage == AssessmentLanguage.hindi
                                ? 'हिंदी'
                                : 'HI-EN'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                onPressed: () {
                  AssessmentLanguageSheet.show(
                    context,
                    currentLanguage: _currentLanguage,
                    onSelect: (lang) => setState(() => _currentLanguage = lang),
                  );
                },
              ),
              TextButton(
                onPressed: () {
                  context.read<HairTestCubit>().startRetest();
                  context.push(RouteNames.hairTest);
                },
                child: Text(
                  AssessmentTranslations.t('retest', _currentLanguage),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                final cubit = context.read<HairTestCubit?>();
                await Future.wait([
                  cubit?.refreshClinicalReports() ?? Future.value(),
                  cubit?.fetchAiAssessment(forceRefresh: true) ??
                      Future.value(),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
                  32,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Expert Clinical Review Status Notice Card
                        ExpertReviewNoticeCard(
                          state: state,
                          isReviewed: isReviewed,
                          isUnderReview: isUnderReview,
                          language: _currentLanguage,
                        ),

                        const SizedBox(height: 16),

                        // 2. Main Diagnosis Overview Card
                        AssessmentOverviewCard(
                          state: state,
                          language: _currentLanguage,
                        ),

                        // Clinician fallback banner if AI is not available
                        if (aiUnavailable) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      LucideIcons.stethoscope,
                                      color: Color(0xFF1D4ED8),
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'The Assistant cannot safely prepare guidance for this assessment. Please contact the clinic for your next step.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isCritical) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _contactDoctorOnWhatsApp,
                                    icon: const Icon(
                                      LucideIcons.messageCircle,
                                      size: 16,
                                    ),
                                    label: const Text('Contact the clinic'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // 3. AI Clinical Trichology & Recommendations
                        if (state.aiAssessment != null &&
                            state.aiAssessment!.isAvailable) ...[
                          const SizedBox(height: 20),
                          AiAssessmentCards(
                            aiAssessment: state.aiAssessment!,
                            assessmentReferenceNo: state.referenceNo,
                            onRefresh: _retryAiAssessment,
                            isRefreshing: _isRequestingAi,
                            onGenerateDietPlan: () async {
                              await context
                                  .read<HairTestCubit>()
                                  .generatePersonalizedDietPlan();
                            },
                            isGeneratingDietPlan: state.isGeneratingDietPlan,
                            dietPlanError: state.dietPlanError,
                            onGenerateRoutine: () async {
                              await context
                                  .read<HairTestCubit>()
                                  .generatePersonalizedRoutine();
                            },
                            isGeneratingRoutine: state.isGeneratingRoutine,
                            routineError: state.routineError,
                          ),
                          const SizedBox(height: 20),
                          AssessmentRecommendationCard(
                            state: state,
                            aiAssessment: state.aiAssessment!,
                            recommendedProducts: recommendedProducts,
                            onConnectWhatsApp: () =>
                                _contactDoctorOnWhatsApp(state),
                            onAddToCart: (product) {
                              final cartCubit = context.read<CartCubit?>();
                              if (cartCubit != null) {
                                final plan = product.supplyPlans.isNotEmpty
                                    ? product.supplyPlans.first
                                    : const ProductSupplyPlan(
                                        title: '1 Month',
                                        subtitle: 'Monthly Supply',
                                        price: 499,
                                        mrp: 599,
                                      );
                                cartCubit.addProduct(
                                  product: product,
                                  plan: plan,
                                  quantity: 1,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${product.name} added to cart',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          AssessmentProductUsageRemindersCard(
                            aiAssessment: state.aiAssessment!,
                            recommendedProducts: recommendedProducts,
                            language: _currentLanguage,
                          ),
                          const SizedBox(height: 20),
                          AssessmentActionableSuggestionsCard(
                            state: state,
                            aiAssessment: state.aiAssessment!,
                            language: _currentLanguage,
                          ),
                          const SizedBox(height: 14),
                          // PDF Slip Card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDFA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF99F6E4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0F766E),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.fileText,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Official Clinical Summary (PDF)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF134E4A),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Doctor-signed prescription slip with diagnosis & regimen.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      AssessmentPdfGenerator.downloadOrPrint(
                                        widget.state,
                                      ),
                                  icon: const Icon(
                                    LucideIcons.download,
                                    size: 13,
                                  ),
                                  label: const Text(
                                    'PDF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F766E),
                                    side: const BorderSide(
                                      color: Color(0xFF0F766E),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (state.referenceNo != null &&
                            state.referenceNo!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.sparkles,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assessment Analysis',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'AI screening summary, possible factors, and daily care ideas.',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _isRequestingAi
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _retryAiAssessment,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          'Analyze',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],

                        // 4. Doctor's Prescribed Regimen (if reviewed by doctor)
                        if (state.doctorCarePlan != null) ...[
                          const SizedBox(height: 20),
                          DoctorClinicalCarePlanCard(
                            carePlan: state.doctorCarePlan!,
                            language: _currentLanguage,
                          ),
                        ],

                        // 5. Doctor's Clinical Reports Section (if available)
                        if (state.clinicalReports.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          DoctorClinicalDocumentsCard(
                            reports: state.clinicalReports,
                            language: _currentLanguage,
                          ),
                        ],

                        // 6. Prominently & Elegantly Displayed Scalp Photos with Zoom
                        const SizedBox(height: 20),
                        ScalpPhotosGalleryCard(
                          state: state,
                          aiAssessment: state.aiAssessment,
                          language: _currentLanguage,
                        ),

                        // Clinician consultation suggestion if recommended
                        if (aiRecommendsDoctor &&
                            (state.aiAssessment == null ||
                                !state.aiAssessment!.isAvailable)) ...[
                          const SizedBox(height: 20),
                          DoctorConsultationActionCard(
                            isHero: true,
                            reason: state.aiAssessment?.nextStepReason,
                            language: _currentLanguage,
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 7. What You Shared & Disclaimer
                        AssessmentLifestyleSummaryCard(
                          state: state,
                          language: _currentLanguage,
                        ),

                        const SizedBox(height: 24),

                        // 8. Next steps & routine setup
                        if (!isCritical) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primary100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AssessmentTranslations.t(
                                    'your_next_steps',
                                    _currentLanguage,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  careRoutineSteps.isNotEmpty
                                      ? AssessmentTranslations.t(
                                          'next_steps_desc',
                                          _currentLanguage,
                                        )
                                      : 'Track your daily care habits and note changes over time.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.secondaryDark,
                                  ),
                                ),
                                if (careRoutineSteps.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  for (final step in careRoutineSteps.take(3))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 55,
                                            height: 24,
                                            alignment: Alignment.center,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary5,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              step.step,
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              step.instruction,
                                              style: const TextStyle(
                                                color: AppColors.primaryDark,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 16),
                                AppButton(
                                  height: 45,
                                  text: careRoutineSteps.isNotEmpty
                                      ? (_isAddingRoutine
                                            ? 'Adding routine…'
                                            : 'Add care plan to my routine')
                                      : 'Open my routine tracker',
                                  variant: AppButtonVariant.filled,
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  onPressed: _isAddingRoutine
                                      ? null
                                      : () => _saveAssessmentRoutine(
                                          context,
                                          careRoutineSteps,
                                        ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextButton(
                                        onPressed: () => context.push(
                                          RouteNames.reminders,
                                        ),
                                        child: const Text('Set a reminder'),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: TextButton(
                                        onPressed: () => context.push(
                                          RouteNames.progress,
                                          extra: true,
                                        ),
                                        child: const Text(
                                          'Add progress photo',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 9. Return to Home
                        AppButton(
                          height: 48,
                          text: 'Done',
                          variant: AppButtonVariant.outlined,
                          size: AppButtonSize.large,
                          width: double.infinity,
                          onPressed: () {
                            context.read<HairTestCubit>().dismissReport();
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go(RouteNames.mainShell);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCritical) ...[
                    AppButton(
                      height: 48,
                      text: 'Book In-Clinic Consultation',
                      variant: AppButtonVariant.filled,
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      icon: const Icon(
                        LucideIcons.calendarCheck,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          context.push(RouteNames.clinicAppointment),
                    ),
                  ] else if (aiUnavailable) ...[
                    AppButton(
                      height: 48,
                      text: 'Contact doctor on WhatsApp',
                      variant: AppButtonVariant.filled,
                      backgroundColor: AppColors.whatsapp,
                      foregroundColor: Colors.white,
                      icon: const Icon(
                        LucideIcons.messageCircle,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () => _contactDoctorOnWhatsApp(state),
                    ),
                  ] else ...[
                    AppButton(
                      height: 48,
                      text: _isAddingRoutine
                          ? 'Adding care plan…'
                          : 'Open daily care routine',
                      variant: AppButtonVariant.filled,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      icon: const Icon(
                        LucideIcons.listChecks,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: _isAddingRoutine
                          ? null
                          : () => _saveAssessmentRoutine(
                              context,
                              careRoutineSteps,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _contactDoctorOnWhatsApp(state),
                            icon: const Icon(
                              LucideIcons.messageCircle,
                              size: 15,
                            ),
                            label: const Text(
                              'WhatsApp doctor',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () =>
                                context.push(RouteNames.clinicAppointment),
                            icon: const Icon(
                              LucideIcons.calendarCheck2,
                              size: 15,
                            ),
                            label: const Text(
                              'Book consultation',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              AssessmentPdfGenerator.downloadOrPrint(
                                widget.state,
                              ),
                          icon: const Icon(LucideIcons.fileDown, size: 14),
                          label: const Text(
                            'Download PDF',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              AssessmentPdfGenerator.sharePdf(widget.state),
                          icon: const Icon(LucideIcons.share2, size: 14),
                          label: const Text(
                            'Share Summary',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
