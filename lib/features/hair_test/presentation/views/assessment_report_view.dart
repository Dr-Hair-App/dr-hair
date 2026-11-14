import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/custom_cached_image.dart';
import '../../../../core/widgets/photo_source_bottom_sheet.dart';
import '../../../care/presentation/viewmodels/care_cubit.dart';
import '../../../shop/data/models/product_model.dart';
import '../../../shop/presentation/viewmodels/cart_cubit.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../viewmodels/hair_test_cubit.dart';
import '../viewmodels/hair_test_state.dart';
import '../widgets/ai_analysis_loading_overlay.dart';
import '../widgets/ai_assessment_cards.dart';

/// The Clinical Assessment Report View displaying the patient's hair test diagnosis,
/// verified doctor reports, uploaded scalp photos, personalized recommended products,
/// and in-clinic doctor consultation options.
class AssessmentReportView extends StatefulWidget {
  final HairTestState state;

  const AssessmentReportView({super.key, required this.state});

  @override
  State<AssessmentReportView> createState() => _AssessmentReportViewState();
}

class _AssessmentReportViewState extends State<AssessmentReportView> {
  late bool _isRequestingAi;
  bool _isAddingRoutine = false;

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

  Future<void> _contactDoctorOnWhatsApp() async {
    const phoneNumber = '917240005000';
    const message =
        'Hello, I completed the Dr. Hair assessment and would like guidance on my next steps.';
    final uri = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please try again.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open WhatsApp. Please try again.'),
          ),
        );
      }
    }
  }

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
    return _buildReportContent();
  }

  Widget _buildReportContent() {
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
        final selectedPattern = _selectedPatternIllustration(state);
        final String trimmedName = state.name.trim();
        final String displayName = trimmedName.isNotEmpty
            ? '${trimmedName[0].toUpperCase()}${trimmedName.substring(1)}, ${state.age}'
            : 'Patient, ${state.age}';

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
        final hideAiAnalysis = aiUnavailable || aiAssessment.requiresClinician;
        final aiNeedsClinician = !isReviewed && hideAiAnalysis;
        final aiRecommendsDoctor =
            !isReviewed &&
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
              'Assessment Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  context.read<HairTestCubit>().startRetest();
                  context.push(RouteNames.hairTest);
                },
                child: const Text(
                  'Retest',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await context.read<HairTestCubit?>()?.refreshClinicalReports();
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
                        // 1. Expert Clinical Review Status Notice
                        _buildExpertReviewNoticeCard(
                          context,
                          state,
                          isReviewed,
                          isUnderReview,
                        ),

                        const SizedBox(height: 16),

                        // 2. Main Diagnosis Card
                        if (aiNeedsClinician)
                          _buildClinicianOnlyNotice(
                            showClinicContact: !aiRecommendsDoctor,
                          )
                        else
                          _buildMainDiagnosisCard(
                            state,
                            selectedPattern,
                            displayName,
                          ),

                        // AI Clinical Trichology & Recommendations
                        if (state.aiAssessment != null && !hideAiAnalysis) ...[
                          const SizedBox(height: 20),
                          AiAssessmentCards(
                            aiAssessment: state.aiAssessment!,
                            assessmentReferenceNo: state.referenceNo,
                            onRefresh: _retryAiAssessment,
                            isRefreshing: _isRequestingAi,
                            onGenerateDietPlan: aiRecommendsDoctor
                                ? null
                                : () async {
                                    await context
                                        .read<HairTestCubit>()
                                        .generatePersonalizedDietPlan();
                                  },
                            isGeneratingDietPlan: state.isGeneratingDietPlan,
                            dietPlanError: state.dietPlanError,
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Dr. Hair Assistant Analysis',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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

                        // 3. Doctor's Prescribed Regimen (if reviewed by doctor)
                        if (state.doctorCarePlan != null) ...[
                          const SizedBox(height: 20),
                          _buildDoctorPrescribedCarePlanCard(
                            context,
                            state.doctorCarePlan!,
                          ),
                        ],

                        // 4. Doctor's Clinical Report Section (if available)
                        if (state.clinicalReports.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildDoctorClinicalReportsSection(
                            context,
                            state.clinicalReports,
                          ),
                        ],

                        const SizedBox(height: 20),
                        _buildScalpPhotosSection(context, state),

                        // Keep clinician guidance and daily care ahead of optional products.
                        if (aiRecommendsDoctor) ...[
                          const SizedBox(height: 20),
                          _buildDoctorAppointmentCard(
                            context,
                            isHero: true,
                            reason: state.aiAssessment?.nextStepReason,
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 8. Summary Card
                        _buildSummaryCard(state),

                        const SizedBox(height: 16),

                        // 9. Medical Disclaimer Box
                        _buildDisclaimerBox(),

                        const SizedBox(height: 24),

                        // 10. Next steps & routine setup
                        if (!aiNeedsClinician)
                          _buildPostAssessmentNextSteps(context, state),

                        // Products are optional support, shown after the care plan.
                        if (!aiNeedsClinician &&
                            state.aiAssessment?.isAvailable == true) ...[
                          const SizedBox(height: 20),
                          _buildRecommendedProductsSection(
                            context,
                            recommendedProducts,
                            isCheckingAvailability: false,
                            availabilityError:
                                aiAssessment?.productAvailabilityStatus ==
                                'unavailable',
                            shopEnabled: aiAssessment?.shopEnabled == true,
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 11. Return to Home
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
                  if (aiRecommendsDoctor || aiUnavailable)
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
                      onPressed: _contactDoctorOnWhatsApp,
                    )
                  else
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
                  if (!aiRecommendsDoctor &&
                      state.aiAssessment?.isAvailable == true) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _contactDoctorOnWhatsApp,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpertReviewNoticeCard(
    BuildContext context,
    HairTestState state,
    bool isReviewed,
    bool isUnderReview,
  ) {
    Color cardBg;
    Color borderCol;
    Color iconCol;
    IconData iconData;
    String badgeText;
    String title;
    String subtitle;
    String description;

    if (isReviewed) {
      cardBg = const Color(0xFFF0FDF4);
      borderCol = const Color(0xFFBBF7D0);
      iconCol = const Color(0xFF16A34A);
      iconData = LucideIcons.badgeCheck;
      badgeText = 'Clinical Review Completed';
      title = 'Clinical review is complete';
      final reviewer = _reviewerName(state.doctorCarePlan);
      subtitle = reviewer == null ? '' : 'Reviewed by $reviewer';
      description = state.doctorCarePlan != null
          ? 'A clinician care plan has been added to this assessment.'
          : 'A clinical review has been recorded for this assessment.';
    } else if (isUnderReview) {
      cardBg = const Color(0xFFEFF6FF);
      borderCol = const Color(0xFFBFDBFE);
      iconCol = const Color(0xFF2563EB);
      iconData = LucideIcons.hourglass;
      badgeText = 'Scalp Photos Under Review';
      title = 'Clinical review in progress';
      subtitle = '';
      description = 'Your assessment is with the clinical team. We will show their review here when it is ready.';
    } else {
      cardBg = const Color(0xFFFFFBEB);
      borderCol = const Color(0xFFFDE68A);
      iconCol = const Color(0xFFD97706);
      iconData = LucideIcons.clock;
      badgeText = 'Assessment Submitted';
      title = 'Your assessment is ready';
      subtitle = '';
      description =
          state.aiAssessment == null ||
              !state.aiAssessment!.isAvailable ||
              state.aiAssessment!.requiresClinician
          ? 'A clinician review is needed before care suggestions are shown.'
          : 'Your assessment summary and available next steps are shown below.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: Icon(iconData, color: iconCol, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderCol),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: iconCol,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildReviewTracker(
            isReviewed: isReviewed,
            isUnderReview: isUnderReview,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTracker({
    required bool isReviewed,
    required bool isUnderReview,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildTrackerStep(
            'Intake Sent',
            isDone: true,
            isActive: false,
            isLast: false,
          ),
          _buildTrackerStep(
            'Doctor Review',
            isDone: isReviewed,
            isActive: isUnderReview || !isReviewed,
            isLast: false,
          ),
          _buildTrackerStep(
            'Regimen Prescribed',
            isDone: isReviewed,
            isActive: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerStep(
    String label, {
    required bool isDone,
    required bool isActive,
    required bool isLast,
  }) {
    Color circleColor = const Color(0xFFE2E8F0);
    Color textColor = const Color(0xFF94A3B8);
    IconData icon = LucideIcons.circle;

    if (isDone) {
      circleColor = const Color(0xFF16A34A);
      textColor = const Color(0xFF166534);
      icon = LucideIcons.check;
    } else if (isActive) {
      circleColor = const Color(0xFF2563EB);
      textColor = const Color(0xFF1E40AF);
      icon = LucideIcons.clock;
    }

    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isDone || isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Container(
              width: 16,
              height: 2,
              margin: const EdgeInsets.only(bottom: 14),
              color: isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            ),
        ],
      ),
    );
  }

  Widget _buildMainDiagnosisCard(
    HairTestState state,
    ({String label, String asset})? selectedPattern,
    String displayName,
  ) {
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
              const Text(
                'ASSESSMENT OVERVIEW',
                style: TextStyle(
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
          if (selectedPattern != null) ...[
            const SizedBox(height: 14),
            _buildSelectedPatternCard(selectedPattern),
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
                      state.stageTitle,
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
                const Text(
                  'Your reported concern',
                  style: TextStyle(
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

  Widget _buildClinicianOnlyNotice({required bool showClinicContact}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.stethoscope, color: Color(0xFF1D4ED8), size: 20),
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
          if (showClinicContact) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _contactDoctorOnWhatsApp,
              icon: const Icon(LucideIcons.messageCircle, size: 16),
              label: const Text('Contact the clinic'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoctorPrescribedCarePlanCard(
    BuildContext context,
    Map<String, dynamic> plan,
  ) {
    final String instructions =
        plan['instructions']?.toString() ??
        'Follow daily application schedule as directed.';
    final String? nextReview = plan['next_review_date']?.toString();
    final List medications = (plan['medications'] as List?) ?? [];

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
                    const Text(
                      'Clinical care plan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    if (_reviewerName(plan) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Prepared by ${_reviewerName(plan)}',
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
          const Text(
            'Clinical Regimen Instructions',
            style: TextStyle(
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
            const Text(
              'Prescribed Formulations & Dosage',
              style: TextStyle(
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
                  'Next Clinical Review: $nextReview',
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

  Widget _buildSelectedPatternCard(({String label, String asset}) pattern) {
    return Container(
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
            width: 82,
            height: 86,
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
                const Text(
                  'Your selected pattern',
                  style: TextStyle(
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
                const Text(
                  'Matches your self-reported hairline or crown shedding.',
                  style: TextStyle(
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
    );
  }

  Widget _buildScalpPhotosSection(BuildContext context, HairTestState state) {
    final angles = ['front', 'top', 'crown', 'left', 'right', 'back'];
    final labels = {
      'front': 'Front Hairline',
      'top': 'Top View',
      'crown': 'Crown Vertex',
      'left': 'Left Temple',
      'right': 'Right Temple',
      'back': 'Back Scalp',
    };

    final hasAnyPhotos = state.photos.values.any((p) => p.trim().isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.camera,
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
                      'Clinical Scalp Photos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'AI checks that photos show a scalp; it does not diagnose from images.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasAnyPhotos) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: angles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final angle = angles[index];
                final photoPath = state.photos[angle];
                final label = labels[angle] ?? angle;

                if (photoPath == null || photoPath.trim().isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          LucideIcons.image,
                          size: 20,
                          color: AppColors.secondaryDark,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Missing',
                          style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final isLocal =
                    !photoPath.startsWith('http://') &&
                    !photoPath.startsWith('https://');

                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      isLocal
                          ? Image.file(File(photoPath), fit: BoxFit.cover)
                          : CustomCachedImage(
                              imageUrl: photoPath,
                              fit: BoxFit.cover,
                            ),
                      Container(
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.imageOff,
                    size: 28,
                    color: AppColors.secondaryDark,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No scalp photos attached',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'You can add photos anytime for more precise clinical tracking.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          AppButton(
            height: 42,
            text: hasAnyPhotos ? 'Update scalp photos' : 'Add scalp photos',
            variant: AppButtonVariant.outlined,
            icon: const Icon(LucideIcons.upload, size: 14),
            onPressed: () => _openScalpPhotoUpdater(context),
          ),
        ],
      ),
    );
  }

  void _openScalpPhotoUpdater(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select photo angle to capture',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Clear scalp photos help Dr. Hair clinicians assess hairline and vertex follicles accurately.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryDark),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _angleChip(sheetCtx, 'front', 'Front Hairline'),
                _angleChip(sheetCtx, 'top', 'Top View'),
                _angleChip(sheetCtx, 'crown', 'Crown Vertex'),
                _angleChip(sheetCtx, 'left', 'Left Temple'),
                _angleChip(sheetCtx, 'right', 'Right Temple'),
                _angleChip(sheetCtx, 'back', 'Back Scalp'),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _angleChip(BuildContext context, String angle, String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        Navigator.pop(context);
        _pickPhotoForAngle(context, angle);
      },
    );
  }

  void _pickPhotoForAngle(BuildContext context, String angle) {
    final cubit = context.read<HairTestCubit>();
    PhotoSourceBottomSheet.show(
      context,
      title: 'Upload $angle photo',
      onSelectSource: (source) => cubit.pickPhoto(label: angle, source: source),
    );
  }

  Widget _buildRecommendedProductsSection(
    BuildContext context,
    List<ProductItem> products, {
    required bool isCheckingAvailability,
    required bool availabilityError,
    required bool shopEnabled,
  }) {
    const stageTitle = 'Optional products';
    const stageSubtitle =
        'Only consider these alongside your care plan, if they suit you.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                  color: AppColors.primary5,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.sparkles,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Optional suggestions',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stageTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stageSubtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isCheckingAvailability)
            const Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Checking current stock…',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryDark,
                  ),
                ),
              ],
            )
          else if (availabilityError)
            const Text(
              'We couldn’t confirm current stock, so no products are being suggested. You can contact the clinic for guidance.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.secondaryDark,
              ),
            )
          else if (products.isEmpty)
            Text(
              shopEnabled
                  ? 'No matching in-stock products are available right now. Your care steps remain available above.'
                  : 'Product suggestions are currently turned off. Your care steps remain available above.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.secondaryDark,
              ),
            ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final product in products) ...[
              _buildProductCard(context, product),
              const SizedBox(height: 12),
            ],
          ],
          if (!shopEnabled || availabilityError || products.isEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _contactDoctorOnWhatsApp,
                icon: const Icon(LucideIcons.messageCircle, size: 16),
                label: const Text('Ask the clinic for guidance'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push(RouteNames.products),
                icon: const Icon(
                  LucideIcons.shoppingBag,
                  size: 14,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Browse the catalog',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductItem product) {
    final plan = product.supplyPlans.isNotEmpty
        ? product.supplyPlans.first
        : ProductSupplyPlan(
            title: 'Standard',
            subtitle: product.subtitle,
            price: 999,
            mrp: 1299,
          );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary5.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58,
              height: 58,
              child: CustomCachedImage(
                imageUrl: product.images.isNotEmpty
                    ? product.images.first
                    : ProductItem.fallbackProductImageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '₹${plan.price.toInt()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (plan.mrp > plan.price)
                      Text(
                        '₹${plan.mrp.toInt()}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (!product.inStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'This item is no longer in stock. Contact the clinic for guidance.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final cart = context.read<CartCubit?>();
              if (cart != null) {
                cart.addProduct(product: product, plan: plan, quantity: 1);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} added to cart!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(
                      label: 'View Cart',
                      textColor: Colors.white,
                      onPressed: () => context.push(RouteNames.cart),
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 12),
                SizedBox(width: 4),
                Text(
                  'Add',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorAppointmentCard(
    BuildContext context, {
    bool isHero = false,
    String? reason,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHero ? const Color(0xFF93C5FD) : const Color(0xFFBFDBFE),
          width: isHero ? 1.5 : 1.0,
        ),
        boxShadow: isHero
            ? [
                BoxShadow(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isHero) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.alertCircle, size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Clinician review suggested',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.stethoscope,
                  color: Color(0xFF1D4ED8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHero
                          ? 'In-Person Clinical Consultation Recommended'
                          : 'Prefer an In-Person Clinical Assessment?',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Contact the clinic team for an in-person review',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isHero
                ? (reason?.trim().isNotEmpty == true
                      ? reason!.trim()
                      : 'Your assessment suggests an in-person clinician review would be helpful. A clinician can assess the pattern and discuss suitable next steps with you.')
                : 'Get a comprehensive digital trichoscopy examination, clinical blood biomarker review, and doctor-prescribed customized treatment regimen at Dr. Hair OPD Clinic.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF1E40AF),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            height: 50,
            text: isHero
                ? 'Book In-Person Consultation (₹500)'
                : 'Book Consultation (₹500)',
            variant: AppButtonVariant.filled,
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            icon: const Icon(
              LucideIcons.calendarCheck2,
              size: 16,
              color: Colors.white,
            ),
            onPressed: () => context.push(RouteNames.clinicAppointment),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorClinicalReportsSection(
    BuildContext context,
    List<Map<String, dynamic>> reports,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
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
                  LucideIcons.fileCheck2,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clinical documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Shared with your care team',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF15803D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Documents shared with you by the clinic are available below.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 16),
          ...reports.map((report) {
            final String title =
                report['title']?.toString() ?? 'Clinical Hair & Scalp Report';
            final String fileName =
                report['file_name']?.toString() ?? 'report.pdf';
            final String reportId = report['id']?.toString() ?? '';
            final num bytes = (report['bytes'] as num?) ?? 1024;
            final String sizeStr = bytes / 1024 < 1000
                ? '${(bytes / 1024).toStringAsFixed(0)} KB'
                : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCFCE7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.fileText,
                        size: 18,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      Text(
                        sizeStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: Color(0xFFBBF7D0)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(LucideIcons.fileText, size: 14),
                          label: const Text(
                            'View PDF',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () async {
                            final cubit = context.read<HairTestCubit?>();
                            final uri = await cubit?.getReportDownloadUri(
                              reportId,
                            );
                            if (uri != null && context.mounted) {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(LucideIcons.shoppingBag, size: 14),
                          label: const Text(
                            'Order Kit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            context.push(RouteNames.products);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
      for (final step in routineSteps.take(3)) {
        final title = 'Assessment plan · ${step.step}';
        if (careCubit.state.routineTasks.any((task) => task.title == title)) {
          continue;
        }
        await careCubit.addCustomRoutineTask(
          title: title,
          subtitle: step.instruction,
          category: 'Daily care',
          timeOfDay: step.step,
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingRoutine = false);
    }
    if (!context.mounted) return;
    context.push(RouteNames.routine);
  }

  Widget _buildPostAssessmentNextSteps(
    BuildContext context,
    HairTestState assessmentState,
  ) {
    final hairState = context.watch<HairTestCubit>().state;
    final hasCompletedAssessment =
        hairState.isCompleted && !hairState.isRetesting;
    final routineSteps = assessmentState.aiAssessment?.isAvailable == true
        ? assessmentState.aiAssessment!.recommendedRegimen.dailySteps
        : <AiRegimenStep>[];

    if (!hasCompletedAssessment) {
      return Container(
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
            const Text(
              'Want your own care plan?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Complete the hair screening to get practical care steps and guidance on whether a clinician should review your condition.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.secondaryDark,
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Take Hair Assessment',
              variant: AppButtonVariant.filled,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () {
                context.read<HairTestCubit>().startRetest();
                context.push(RouteNames.hairTest);
              },
            ),
          ],
        ),
      );
    }

    return Container(
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
          const Text(
            'Your next steps',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            routineSteps.isNotEmpty
                ? 'Start with these simple, non-prescription care steps. Products are optional; a clinician can guide treatment when needed.'
                : 'Track your daily care habits and note changes over time.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.secondaryDark,
            ),
          ),
          if (routineSteps.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final step in routineSteps.take(3))
              _nextStepRow(step.step, step.instruction),
          ],
          const SizedBox(height: 16),
          AppButton(
            height: 45,
            text: routineSteps.isNotEmpty
                ? (_isAddingRoutine
                      ? 'Adding routine…'
                      : 'Add care plan to my routine')
                : 'Open my routine tracker',
            variant: AppButtonVariant.filled,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            onPressed: _isAddingRoutine
                ? null
                : () => _saveAssessmentRoutine(context, routineSteps),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextButton(
                  onPressed: () => context.push(RouteNames.reminders),
                  child: const Text('Set a reminder'),
                ),
              ),
              Expanded(
                flex: 4,
                child: TextButton(
                  onPressed: () =>
                      context.push(RouteNames.progress, extra: true),
                  child: const Text('Add progress photo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nextStepRow(String number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary5,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
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
              title,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(HairTestState state) {
    final details = [
      (key: 'Gender', value: state.selectedGender ?? 'Not selected'),
      (key: 'Age', value: state.age.isNotEmpty ? state.age : 'Not specified'),
      if (state.primaryConcern != null && state.primaryConcern!.isNotEmpty)
        (key: 'Main Concern', value: state.primaryConcern!),
      if (state.duration != null && state.duration!.isNotEmpty)
        (key: 'Duration', value: state.duration!),
      if (state.dandruff != null && state.dandruff!.isNotEmpty)
        (key: 'Dandruff Status', value: state.dandruff!),
      if (state.familyHistory != null && state.familyHistory!.isNotEmpty)
        (key: 'Family History', value: state.familyHistory!),
      if (state.gutHealth != null && state.gutHealth!.isNotEmpty)
        (key: 'Gut Health', value: state.gutHealth!),
      if (state.stressLevel != null && state.stressLevel!.isNotEmpty)
        (key: 'Stress Level', value: state.stressLevel!),
    ];

    return Container(
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
          const Text(
            'WHAT YOU SHARED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'These are the details you selected for this assessment.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.secondaryDark,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < details.length; index++) ...[
            if (index > 0) const Divider(height: 16, color: AppColors.border),
            _buildSummaryRow(details[index].key, details[index].value),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimerBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.stethoscope, color: Color(0xFFD97706), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to use this result',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This summary is based on your answers and is not a medical diagnosis. A qualified clinician can assess your symptoms and discuss suitable care.',
                  style: TextStyle(
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

({String label, String asset})? _selectedPatternIllustration(
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
