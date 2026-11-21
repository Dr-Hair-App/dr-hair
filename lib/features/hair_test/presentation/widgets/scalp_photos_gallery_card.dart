import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../care/presentation/widgets/care_widgets.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_state.dart';

/// Prominently displays the patient's uploaded scalp photos using the unified
/// Hair Progress Journey card design, with full pinch-to-zoom interactive viewer,
/// AI scalp verification indicators, and multilingual support.
class ScalpPhotosGalleryCard extends StatelessWidget {
  final HairTestState state;
  final AiAssessmentModel? aiAssessment;
  final AssessmentLanguage language;

  const ScalpPhotosGalleryCard({
    super.key,
    required this.state,
    this.aiAssessment,
    this.language = AssessmentLanguage.english,
  });

  String? _findPhotoPath(List<String> aliases) {
    // 1. Check direct from state.photos
    for (final a in aliases) {
      final val = state.photos[a];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    // Case-insensitive check on state.photos keys
    for (final entry in state.photos.entries) {
      if (entry.value.trim().isNotEmpty) {
        final keyLower = entry.key.toLowerCase();
        for (final a in aliases) {
          if (keyLower == a.toLowerCase() ||
              keyLower.contains(a.toLowerCase())) {
            return entry.value.trim();
          }
        }
      }
    }

    // 2. Check direct from state.optimizedPhotos
    for (final a in aliases) {
      final val = state.optimizedPhotos[a];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    }
    for (final entry in state.optimizedPhotos.entries) {
      if (entry.value.trim().isNotEmpty) {
        final keyLower = entry.key.toLowerCase();
        for (final a in aliases) {
          if (keyLower == a.toLowerCase() ||
              keyLower.contains(a.toLowerCase())) {
            return entry.value.trim();
          }
        }
      }
    }

    // 3. Check photoAnalysis
    for (final entry in state.photoAnalysis.entries) {
      final path = entry.value.photoPath.trim();
      if (path.isNotEmpty) {
        final labelLower = entry.key.toLowerCase();
        for (final a in aliases) {
          if (labelLower == a.toLowerCase() ||
              labelLower.contains(a.toLowerCase())) {
            return path;
          }
        }
      }
    }

    // 4. Check aiAssessment scalpPhotoVerification records
    if (aiAssessment != null) {
      for (final item in aiAssessment!.scalpPhotoVerification) {
        final angle = item['angle']?.toString().toLowerCase() ?? '';
        final fileName = item['file_name']?.toString().toLowerCase() ?? '';
        final url = item['url']?.toString() ??
            item['photo_url']?.toString() ??
            item['path']?.toString() ??
            item['image_url']?.toString();

        if (url != null && url.trim().isNotEmpty) {
          for (final a in aliases) {
            final aLower = a.toLowerCase();
            if (angle == aLower ||
                angle == 'photo_$aLower' ||
                fileName.contains(aLower) ||
                angle.contains(aLower)) {
              return url.trim();
            }
          }
        }
      }
    }

    return null;
  }

  void _showFullScreenPhoto(
    BuildContext context,
    String imagePath,
    String title,
  ) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Colors.black,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.5,
                      child: buildCarePhotoWidget(
                        imagePath,
                        height: 400,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: Colors.black.withValues(alpha: 0.88),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.camera,
                                  color: Colors.white70,
                                  size: 15,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              AssessmentTranslations.t('close', language),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.65),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(LucideIcons.x, size: 20),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail({
    required BuildContext context,
    required String label,
    required String? imagePath,
  }) {
    final hasPhoto = imagePath != null && imagePath.trim().isNotEmpty;
    return Expanded(
      child: GestureDetector(
        onTap: hasPhoto
            ? () => _showFullScreenPhoto(context, imagePath, label)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  hasPhoto
                      ? buildCarePhotoWidget(imagePath, height: 112)
                      : Container(
                          height: 112,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                LucideIcons.camera,
                                size: 22,
                                color: AppColors.secondaryDark,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AssessmentTranslations.t(
                                  'not_uploaded',
                                  language,
                                ),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                  if (hasPhoto)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          LucideIcons.maximize2,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Look up photos using exhaustive alias mapping
    final frontPhoto = _findPhotoPath(const [
      'front',
      'photo_front',
      'Front Hairline',
      'front hairline',
      'Front',
    ]);

    final topPhoto = _findPhotoPath(const [
      'top',
      'photo_top',
      'crown',
      'photo_crown',
      'Crown / Top',
      'Top / Crown',
      'Crown Area',
      'Top View',
      'Top',
      'Crown',
    ]);

    final backPhoto = _findPhotoPath(const [
      'back',
      'photo_back',
      'Back / Vertex',
      'Back Scalp',
      'Back',
      'vertex',
    ]);

    final sidePhoto = _findPhotoPath(const [
      'left',
      'right',
      'temple',
      'temples',
      'Side Profile / Temples',
      'Left Temple',
      'Right Temple',
      'sides',
    ]);

    final hasAnyPhotos = frontPhoto != null ||
        topPhoto != null ||
        backPhoto != null ||
        sidePhoto != null;

    // AI Scalp Verification check
    final isVerified = aiAssessment != null &&
        aiAssessment!.isAvailable &&
        aiAssessment!.scalpPhotoVerification.any(
          (p) =>
              p['status'] == 'hairDetected' ||
              p['verification_status'] == 'hairDetected',
        );

    final rawStage = state.stage?.trim();
    final stageText = rawStage != null && rawStage.isNotEmpty
        ? (rawStage.toLowerCase().startsWith('stage')
            ? rawStage.split(RegExp(r'[-–—]')).first.trim()
            : 'Stage $rawStage')
        : 'Assessment';

    final now = DateTime.now();
    final dateFormatted = '${now.day} ${careMonthName(now.month)} ${now.year}';

    // AI Observation or summary
    final summary = aiAssessment?.summary.trim();
    final nextStep = aiAssessment?.nextStepReason.trim();
    final observationText = summary != null && summary.isNotEmpty
        ? summary
        : (nextStep != null && nextStep.isNotEmpty ? nextStep : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AssessmentTranslations.t('clinical_scalp_photos', language),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    AssessmentTranslations.t('scalp_photos_notice', language),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Hair Progress Journey Style Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Date, Stage & AI Verification status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary5,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.calendar,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                dateFormatted,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.shieldCheck,
                                size: 13,
                                color: Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Text(
                                  stageText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isVerified
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? LucideIcons.sparkles : LucideIcons.camera,
                          size: 12,
                          color: isVerified
                              ? const Color(0xFF059669)
                              : AppColors.secondaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified
                              ? AssessmentTranslations.t(
                                  'ai_verified_badge',
                                  language,
                                )
                              : AssessmentTranslations.t(
                                  'assessment_intake_badge',
                                  language,
                                ),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isVerified
                                ? const Color(0xFF059669)
                                : AppColors.secondaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (hasAnyPhotos) ...[
                // Exactly 3 Intake Angles: Front Hairline, Crown / Top, Side Profile / Temples
                Row(
                  children: [
                    _buildPhotoThumbnail(
                      context: context,
                      label: AssessmentTranslations.t('photo_front', language),
                      imagePath: frontPhoto,
                    ),
                    const SizedBox(width: 8),
                    _buildPhotoThumbnail(
                      context: context,
                      label: AssessmentTranslations.t('photo_top', language),
                      imagePath: topPhoto,
                    ),
                    const SizedBox(width: 8),
                    _buildPhotoThumbnail(
                      context: context,
                      label: AssessmentTranslations.t('photo_side', language),
                      imagePath: sidePhoto ?? backPhoto,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // AI Status & Quality Indicators (Matching Progress Journey)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Hair Loss / Shedding Level Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.activity,
                            size: 12,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Loss Stage: ${state.stage ?? "Evaluation"}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Scalp / Dandruff Indicator
                    if (state.dandruff != null &&
                        state.dandruff!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.shieldAlert,
                              size: 12,
                              color: Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Dandruff: ${state.dandruff}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // AI Clinical Observation Note (Matching Progress Journey Note container)
                if (observationText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary5,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.sparkles,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AssessmentTranslations.t(
                                  'ai_clinical_observation',
                                  language,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                observationText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryDark,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Empty placeholder when no photos are attached
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.imageOff,
                        size: 28,
                        color: AppColors.secondaryDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AssessmentTranslations.t(
                                'no_scalp_photos',
                                language,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AssessmentTranslations.t(
                                'scalp_photos_benefit_desc',
                                language,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}
