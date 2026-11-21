import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_state.dart';

enum ExpertReviewCardLayout { compact, detailed }

enum _ReviewStatus {
  processing,
  clinicianReview,
  underReview,
  reviewed,
  ready,
  failed,
}

/// Reusable, data-driven assessment status card for Home and report screens.
/// Screens can choose compact or detailed layout and provide their own action/copy.
class ExpertReviewNoticeCard extends StatefulWidget {
  final HairTestState state;
  final bool? isReviewed;
  final bool? isUnderReview;
  final AssessmentLanguage language;
  final ExpertReviewCardLayout layout;
  final bool showProgress;
  final bool showReviewer;
  final bool showReference;
  final String? titleOverride;
  final String? messageOverride;
  final String? actionLabel;
  final VoidCallback? onPressed;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryPressed;
  final EdgeInsetsGeometry? padding;

  const ExpertReviewNoticeCard({
    super.key,
    required this.state,
    this.isReviewed,
    this.isUnderReview,
    this.language = AssessmentLanguage.english,
    this.layout = ExpertReviewCardLayout.detailed,
    this.showProgress = true,
    this.showReviewer = true,
    this.showReference = false,
    this.titleOverride,
    this.messageOverride,
    this.actionLabel,
    this.onPressed,
    this.secondaryActionLabel,
    this.onSecondaryPressed,
    this.padding,
  });

  @override
  State<ExpertReviewNoticeCard> createState() => _ExpertReviewNoticeCardState();
}

class _ExpertReviewNoticeCardState extends State<ExpertReviewNoticeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  bool get _isCompact => widget.layout == ExpertReviewCardLayout.compact;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ExpertReviewNoticeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final status = _resolveStatus();
    if (status == _ReviewStatus.processing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  _ReviewStatus _resolveStatus() {
    final reviewed =
        widget.isReviewed ??
        (widget.state.assessmentStatus == 'reviewed' ||
            widget.state.doctorCarePlan != null);
    final underReview =
        widget.isUnderReview ?? widget.state.assessmentStatus == 'under_review';
    final aiStatus = widget.state.aiAssessmentStatus.trim().toLowerCase();

    if (reviewed) return _ReviewStatus.reviewed;
    if (underReview) return _ReviewStatus.underReview;
    if (aiStatus == 'failed' ||
        widget.state.assessmentStatus.trim().toLowerCase() ==
            'ai_processing_failed') {
      return _ReviewStatus.failed;
    }
    if (widget.state.isSubmitting ||
        aiStatus == 'queued' ||
        aiStatus == 'processing') {
      return _ReviewStatus.processing;
    }

    final ai = widget.state.aiAssessment;
    if (ai?.isAvailable == true && ai!.requiresClinician) {
      return _ReviewStatus.clinicianReview;
    }
    if (ai?.isAvailable == true) return _ReviewStatus.ready;
    if (widget.state.isSubmitted ||
        widget.state.assessmentStatus == 'submitted') {
      return _ReviewStatus.clinicianReview;
    }
    return _ReviewStatus.processing;
  }

  String _text(_ReviewStatus status, String part) {
    if (status == _ReviewStatus.reviewed && part == 'body') {
      final hasPlan = widget.state.doctorCarePlan != null;
      final hasNote = widget.state.doctorReviewNote?.trim().isNotEmpty == true;
      return AssessmentTranslations.t(
        hasPlan
            ? 'review_status_reviewed_body'
            : hasNote
            ? 'review_status_reviewed_note'
            : 'review_status_reviewed_recorded',
        widget.language,
      );
    }
    final key = switch ((status, part)) {
      (_ReviewStatus.processing, 'badge') => 'review_status_processing_badge',
      (_ReviewStatus.processing, 'title') => 'review_status_processing_title',
      (_ReviewStatus.processing, _) => 'review_status_processing_body',
      (_ReviewStatus.clinicianReview, 'badge') =>
        'review_status_clinician_badge',
      (_ReviewStatus.clinicianReview, 'title') =>
        'review_status_clinician_title',
      (_ReviewStatus.clinicianReview, _) => 'review_status_clinician_body',
      (_ReviewStatus.underReview, 'badge') =>
        'review_status_under_review_badge',
      (_ReviewStatus.underReview, 'title') =>
        'review_status_under_review_title',
      (_ReviewStatus.underReview, _) => 'review_status_under_review_body',
      (_ReviewStatus.reviewed, 'badge') => 'review_status_reviewed_badge',
      (_ReviewStatus.reviewed, 'title') => 'review_status_reviewed_title',
      (_ReviewStatus.reviewed, _) => 'review_status_reviewed_body',
      (_ReviewStatus.ready, 'badge') => 'review_status_ready_badge',
      (_ReviewStatus.ready, 'title') => 'review_status_ready_title',
      (_ReviewStatus.ready, _) => 'review_status_ready_body',
      (_ReviewStatus.failed, 'badge') => 'review_status_failed_badge',
      (_ReviewStatus.failed, 'title') => 'review_status_failed_title',
      (_ReviewStatus.failed, _) => 'review_status_failed_body',
    };
    return AssessmentTranslations.t(key, widget.language);
  }

  _ReviewPalette _palette(_ReviewStatus status) => switch (status) {
    _ReviewStatus.processing => const _ReviewPalette(
      accent: AppColors.primary,
      tint: Color(0xFFF0FDF4),
      border: Color(0xFFDCFCE7),
      icon: LucideIcons.loaderCircle,
    ),
    _ReviewStatus.clinicianReview => const _ReviewPalette(
      accent: Color(0xFFB45309),
      tint: Color(0xFFFFFBEB),
      border: Color(0xFFFDE68A),
      icon: LucideIcons.stethoscope,
    ),
    _ReviewStatus.underReview => const _ReviewPalette(
      accent: Color(0xFF2563EB),
      tint: Color(0xFFEFF6FF),
      border: Color(0xFFBFDBFE),
      icon: LucideIcons.hourglass,
    ),
    _ReviewStatus.reviewed => const _ReviewPalette(
      accent: Color(0xFF15803D),
      tint: Color(0xFFF0FDF4),
      border: Color(0xFFBBF7D0),
      icon: LucideIcons.badgeCheck,
    ),
    _ReviewStatus.ready => const _ReviewPalette(
      accent: AppColors.primary,
      tint: Color(0xFFF0FDFA),
      border: Color(0xFFBFEAE5),
      icon: LucideIcons.fileCheck2,
    ),
    _ReviewStatus.failed => const _ReviewPalette(
      accent: Color(0xFFB91C1C),
      tint: Color(0xFFFEF2F2),
      border: Color(0xFFFECACA),
      icon: LucideIcons.circleAlert,
    ),
  };

  double _progress(_ReviewStatus status) => switch (status) {
    _ReviewStatus.processing => 0.35,
    _ReviewStatus.clinicianReview => 0.65,
    _ReviewStatus.underReview => 0.85,
    _ReviewStatus.reviewed || _ReviewStatus.ready => 1.0,
    _ReviewStatus.failed => 0.35,
  };

  String? _reviewerName() {
    final plan = widget.state.doctorCarePlan;
    if (plan == null) return null;
    for (final key in ['doctor_name', 'reviewed_by']) {
      final value = plan[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus();
    final palette = _palette(status);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 320);
    final title = widget.titleOverride ?? _text(status, 'title');
    final message = widget.messageOverride ?? _text(status, 'body');
    final reviewer = widget.showReviewer && status == _ReviewStatus.reviewed
        ? _reviewerName()
        : null;

    return TweenAnimationBuilder<double>(
      key: ValueKey(status),
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 6 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: widget.padding ?? EdgeInsets.all(_isCompact ? 14 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_isCompact ? 18 : 20),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: _isCompact ? 40 : 44,
                  height: _isCompact ? 40 : 44,
                  decoration: BoxDecoration(
                    color: palette.tint,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: status == _ReviewStatus.processing
                      ? RotationTransition(
                          turns: _rotationController,
                          child: Icon(
                            palette.icon,
                            color: palette.accent,
                            size: _isCompact ? 20 : 22,
                          ),
                        )
                      : Icon(
                          palette.icon,
                          color: palette.accent,
                          size: _isCompact ? 20 : 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              constraints: const BoxConstraints(maxWidth: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.tint,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                _text(status, 'badge'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.accent,
                                  fontSize: 9.5,
                                  height: 1.1,
                                  letterSpacing: 0.35,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (status == _ReviewStatus.processing)
                              const Text(
                                '·  ~1-2 mins',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: _isCompact ? 15 : 17,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.showReference &&
                    widget.state.referenceNo?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 5),
                    child: Text(
                      widget.state.referenceNo!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.only(left: _isCompact ? 52 : 56),
              child: Text(
                message,
                maxLines: _isCompact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (status == _ReviewStatus.underReview) ...[
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: _isCompact ? 52 : 56),
                child: Row(
                  children: [
                    Icon(LucideIcons.bellRing, size: 12, color: palette.accent),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Notification will be sent once the doctor signs off.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (reviewer != null) ...[
              const SizedBox(height: 5),
              Padding(
                padding: EdgeInsets.only(left: _isCompact ? 52 : 56),
                child: Text(
                  '${AssessmentTranslations.t('reviewed_by', widget.language)} $reviewer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (widget.showProgress) ...[
              SizedBox(height: _isCompact ? 13 : 16),
              if (!_isCompact)
                _buildTimeline(status, palette, duration)
              else
                _buildProgressBar(status, palette, duration),
            ],
            if ((widget.onPressed != null &&
                    widget.actionLabel?.trim().isNotEmpty == true) ||
                (widget.onSecondaryPressed != null &&
                    widget.secondaryActionLabel?.trim().isNotEmpty ==
                        true)) ...[
              SizedBox(height: _isCompact ? 10 : 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final hasSecondary =
                      widget.onSecondaryPressed != null &&
                      widget.secondaryActionLabel?.trim().isNotEmpty == true;
                  final hasPrimary =
                      widget.onPressed != null &&
                      widget.actionLabel?.trim().isNotEmpty == true;

                  Widget secondaryBtn() => TextButton.icon(
                    onPressed: widget.onSecondaryPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      minimumSize: const Size(44, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(LucideIcons.messageCircle, size: 14),
                    label: Text(
                      widget.secondaryActionLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );

                  Widget primaryBtn() => ElevatedButton.icon(
                    onPressed: widget.onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      minimumSize: const Size(44, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(LucideIcons.arrowRight, size: 14),
                    label: Text(
                      widget.actionLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );

                  if (hasSecondary && hasPrimary) {
                    if (constraints.maxWidth < 340) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          primaryBtn(),
                          const SizedBox(height: 6),
                          secondaryBtn(),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [secondaryBtn(), primaryBtn()],
                    );
                  }
                  if (hasPrimary) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: primaryBtn(),
                    );
                  }
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: secondaryBtn(),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(
    _ReviewStatus status,
    _ReviewPalette palette,
    Duration duration,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _progress(status)),
      duration: duration,
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 4,
          backgroundColor: palette.tint,
          color: palette.accent,
        ),
      ),
    );
  }

  Widget _buildTimeline(
    _ReviewStatus status,
    _ReviewPalette palette,
    Duration duration,
  ) {
    final aiReady = widget.state.aiAssessment?.isAvailable == true;
    final doctorActive =
        status == _ReviewStatus.clinicianReview ||
        status == _ReviewStatus.underReview;
    final doctorDone =
        status == _ReviewStatus.reviewed || status == _ReviewStatus.ready;
    final doctorOptional = status == _ReviewStatus.ready;
    final processing = status == _ReviewStatus.processing;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _TimelineStep(
                  label: AssessmentTranslations.t(
                    'intake_done',
                    widget.language,
                  ),
                  isDone: true,
                  isActive: false,
                  optional: false,
                ),
              ),
              _TimelineConnector(isComplete: true),
              Expanded(
                child: _TimelineStep(
                  label: AssessmentTranslations.t(
                    'ai_review_done',
                    widget.language,
                  ),
                  isDone: aiReady,
                  isActive: processing && !aiReady,
                  optional: false,
                ),
              ),
              _TimelineConnector(isComplete: aiReady),
              Expanded(
                child: _TimelineStep(
                  label: AssessmentTranslations.t(
                    'doctor_review_step',
                    widget.language,
                  ),
                  isDone: doctorDone,
                  isActive: doctorActive,
                  optional: doctorOptional,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildProgressBar(status, palette, duration),
          if (doctorOptional) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                AssessmentTranslations.t(
                  'review_timeline_optional',
                  widget.language,
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewPalette {
  final Color accent;
  final Color tint;
  final Color border;
  final IconData icon;

  const _ReviewPalette({
    required this.accent,
    required this.tint,
    required this.border,
    required this.icon,
  });
}

class _TimelineConnector extends StatelessWidget {
  final bool isComplete;

  const _TimelineConnector({required this.isComplete});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 19),
    child: Container(
      width: 18,
      height: 2,
      decoration: BoxDecoration(
        color: isComplete ? const Color(0xFF22A06B) : const Color(0xFFD8E0E9),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final bool optional;

  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.optional,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? const Color(0xFF2563EB)
        : isDone && !optional
        ? const Color(0xFF15803D)
        : const Color(0xFF94A3B8);
    final icon = isActive
        ? LucideIcons.clock3
        : isDone
        ? LucideIcons.check
        : LucideIcons.circle;

    return Column(
      children: [
        AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDone || isActive ? color : Colors.white,
            shape: BoxShape.circle,
            border: isDone || isActive ? null : Border.all(color: color),
          ),
          child: Icon(
            icon,
            size: 12,
            color: isDone || isActive ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 10,
            height: 1.15,
            fontWeight: isDone || isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
