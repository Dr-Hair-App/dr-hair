import 'package:material_ui/material_ui.dart';
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
import '../../../shop/data/models/product_model.dart';
import '../../../shop/presentation/viewmodels/cart_cubit.dart';
import '../../data/services/assessment_pdf_generator.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_cubit.dart';
import '../viewmodels/hair_test_state.dart';
import '../widgets/ai_analysis_loading_overlay.dart';
import '../widgets/ai_assessment_cards.dart';
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
          await cubit.refreshAiAssessmentStatus();
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
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          'Could not retry the AI assessment. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isRequestingAi = false);
    }
  }

  Future<void> _checkAiAssessmentStatus() async {
    if (_isRequestingAi) return;
    setState(() => _isRequestingAi = true);
    try {
      await context.read<HairTestCubit?>()?.refreshAiAssessmentStatus();
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
      AppToast.showError(context, 'Could not open WhatsApp. Please try again.');
    }
  }

  Future<void> _requestDoctorReviewOnWhatsApp(HairTestState state) async {
    final user = context.read<AuthCubit?>()?.state.user;
    final patientDatabaseId = user?.id.trim() ?? '';
    final patientCode = state.patientId?.trim().isNotEmpty == true
        ? state.patientId!.trim()
        : user?.patientId.trim() ?? '';
    final referenceNo = state.referenceNo?.trim() ?? '';
    if (patientDatabaseId.isEmpty ||
        patientCode.isEmpty ||
        referenceNo.isEmpty) {
      AppToast.showError(
        context,
        'Assessment details are not ready yet. Please try again shortly.',
      );
      return;
    }

    final launched = await WhatsAppLauncher.launchAssessmentReviewRequest(
      patientDatabaseId: patientDatabaseId,
      patientCode: patientCode,
      referenceNo: referenceNo,
    );
    if (!launched && mounted) {
      AppToast.showError(context, 'Could not open WhatsApp. Please try again.');
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
      final tasks = routineSteps
          .map(
            (step) => RoutineTask(
              id: 'assessment_plan_${now}_${step.step.replaceAll(' ', '_')}',
              title: 'Assessment plan · ${step.step}',
              subtitle: step.instruction,
              category: 'Daily care',
              timeOfDay: step.step,
              createdBy: 'ai_assessment',
            ),
          )
          .toList();
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
              // Share icon button in AppBar (language selector is in AssessmentOverviewCard)
              IconButton(
                tooltip: 'Share Assessment',
                icon: const Icon(
                  LucideIcons.share2,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
                onPressed: () => AssessmentPdfGenerator.sharePdf(widget.state),
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
                  cubit?.refreshAiAssessmentStatus() ?? Future.value(),
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
                          layout: ExpertReviewCardLayout.detailed,
                          showProgress: true,
                          showReviewer: true,
                          secondaryActionLabel: AssessmentTranslations.t(
                            'review_action_request',
                            _currentLanguage,
                          ),
                          onSecondaryPressed:
                              !isReviewed &&
                                  (aiUnavailable ||
                                      aiAssessment.requiresClinician ||
                                      isUnderReview ||
                                      state.isSubmitting)
                              ? () => _requestDoctorReviewOnWhatsApp(state)
                              : null,
                        ),

                        const SizedBox(height: 16),

                        // 2. Main Diagnosis Overview Card
                        AssessmentOverviewCard(
                          state: state,
                          language: _currentLanguage,
                          onLanguageChanged: (lang) =>
                              setState(() => _currentLanguage = lang),
                        ),

                        // Clinician fallback banner if AI is not available
                        if (aiUnavailable) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          fontSize: 12,
                                          height: 1.45,
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isCritical) ...[
                                  const SizedBox(height: 10),
                                  AppButton(
                                    height: 45,
                                    width: 180,
                                    textStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    onPressed: _contactDoctorOnWhatsApp,
                                    icon: Icon(
                                      LucideIcons.messageCircle,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    text: 'Contact the clinic',
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
                            language: _currentLanguage,
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
                                if (product.supplyPlans.isEmpty) {
                                  context.push(
                                    RouteNames.productPath(product.id),
                                  );
                                  return;
                                }
                                final plan = product.supplyPlans.first;
                                cartCubit.addProduct(
                                  product: product,
                                  plan: plan,
                                  quantity: 1,
                                );
                                if (context.mounted) {
                                  AppToast.showSuccess(
                                    context,
                                    '${product.name} added to cart',
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
                          const SizedBox(height: 14),
                          // This local PDF is an AI summary, not a signed
                          // clinical document.
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
                                        'Assessment Summary (PDF)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF134E4A),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'AI-generated summary for your records. Not a signed clinical report.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AppButton(
                                  height: 34,
                                  text: 'PDF',
                                  icon: const Icon(
                                    LucideIcons.download,
                                    size: 13,
                                    color: Color(0xFF0F766E),
                                  ),
                                  variant: AppButtonVariant.outlined,
                                  foregroundColor: const Color(0xFF0F766E),
                                  borderColor: const Color(0xFF0F766E),
                                  borderRadius: BorderRadius.circular(8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  onPressed: () =>
                                      AssessmentPdfGenerator.downloadOrPrint(
                                        widget.state,
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
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
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
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
                                          fontSize: 10,
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
                                    : AppButton(
                                        onPressed:
                                            state.aiAssessmentStatus ==
                                                    'failed' ||
                                                state.aiAssessmentStatus ==
                                                    'unavailable'
                                            ? _retryAiAssessment
                                            : _checkAiAssessmentStatus,
                                        height: 45,
                                        child: Text(
                                          state.aiAssessmentStatus ==
                                                      'failed' ||
                                                  state.aiAssessmentStatus ==
                                                      'unavailable'
                                              ? 'Try again'
                                              : 'Check status',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
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
                            padding: const EdgeInsets.all(14),
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
                                // const SizedBox(height: 6),
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
                                        onPressed: () =>
                                            context.push(RouteNames.reminders),
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
                                        child: const Text('Add progress photo'),
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                  // ── Primary action (full-width) ──────────────────────────
                  if (isCritical) ...[
                    AppButton(
                      height: 48,
                      width: double.infinity,
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
                  ] else if (!aiUnavailable) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: AppButton(
                        height: 48,
                        width: double.infinity,
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
                    ),
                  ],
                  // const SizedBox(height: 8),
                  // ── WhatsApp Doctor + Retest row (always visible) ────────
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          height: 44,
                          textStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          text: AssessmentTranslations.t(
                            'whatsapp_doctor_bottom',
                            _currentLanguage,
                          ),
                          variant: AppButtonVariant.outlined,
                          borderColor: AppColors.whatsapp,
                          foregroundColor: const Color(0xFF075E54),
                          icon: Image.asset(
                            'assets/icons/whatsapp.png',
                            width: 15,
                            height: 15,
                          ),
                          onPressed: () => _contactDoctorOnWhatsApp(state),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          height: 44,
                          text: AssessmentTranslations.t(
                            'retake_hair_test',
                            _currentLanguage,
                          ),
                          textStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          variant: AppButtonVariant.outlined,
                          icon: const Icon(
                            LucideIcons.refreshCw,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          onPressed: () {
                            context.read<HairTestCubit>().startRetest();
                            context.push(RouteNames.hairTest);
                          },
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
