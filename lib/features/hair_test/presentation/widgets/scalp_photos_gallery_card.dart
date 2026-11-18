import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/custom_cached_image.dart';
import '../../domain/models/ai_assessment_model.dart';
import '../localization/assessment_translations.dart';
import '../viewmodels/hair_test_state.dart';

/// Prominently displays the patient's uploaded scalp photos with angle labels,
/// and provides tap-to-view full-screen preview with pinch-to-zoom.
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

  static const List<String> _angleKeys = [
    'front',
    'top',
    'crown',
    'left',
    'right',
    'back',
  ];

  String _getAngleLabel(String angle) {
    switch (angle) {
      case 'front':
        return AssessmentTranslations.t('photo_front', language);
      case 'top':
        return AssessmentTranslations.t('photo_top', language);
      case 'crown':
        return AssessmentTranslations.t('photo_crown', language);
      case 'left':
        return AssessmentTranslations.t('photo_left', language);
      case 'right':
        return AssessmentTranslations.t('photo_right', language);
      case 'back':
        return AssessmentTranslations.t('photo_back', language);
      default:
        return angle;
    }
  }

  String? _findPhotoPath(String angle) {
    // 1. Direct from state.optimizedPhotos
    final opt = state.optimizedPhotos[angle] ?? state.optimizedPhotos['photo_$angle'];
    if (opt != null && opt.trim().isNotEmpty) return opt.trim();

    // 2. Direct from state.photos
    final raw = state.photos[angle] ?? state.photos['photo_$angle'];
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();

    // 3. From aiAssessment scalpPhotoVerification
    if (aiAssessment != null) {
      for (final item in aiAssessment!.scalpPhotoVerification) {
        final a = item['angle']?.toString().toLowerCase() ?? '';
        final url = item['url']?.toString() ?? item['photo_url']?.toString() ?? item['path']?.toString();
        if ((a == angle || a == 'photo_$angle') && url != null && url.trim().isNotEmpty) {
          return url.trim();
        }
      }
    }

    return null;
  }

  void _openPhotoZoom(BuildContext context, String path, String label) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _isLocalFile(path)
                    ? Image.file(File(path), fit: BoxFit.contain)
                    : CustomCachedImage(imageUrl: path, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.camera, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Pinch or double-tap to zoom',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLocalFile(String path) {
    return !path.startsWith('http://') && !path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final photoMap = <String, String>{};
    for (final angle in _angleKeys) {
      final p = _findPhotoPath(angle);
      if (p != null) photoMap[angle] = p;
    }

    final hasAnyPhotos = photoMap.isNotEmpty;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AssessmentTranslations.t('clinical_scalp_photos', language),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
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
          if (hasAnyPhotos) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  LucideIcons.zoomIn,
                  size: 12,
                  color: AppColors.secondaryDark,
                ),
                const SizedBox(width: 5),
                Text(
                  AssessmentTranslations.t('tap_to_zoom', language),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (hasAnyPhotos) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _angleKeys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) {
                final angle = _angleKeys[index];
                final photoPath = photoMap[angle];
                final label = _getAngleLabel(angle);

                if (photoPath == null || photoPath.trim().isEmpty) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
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

                final isLocal = _isLocalFile(photoPath);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openPhotoZoom(context, photoPath, label),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          isLocal
                              ? Image.file(
                                  File(photoPath),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      LucideIcons.image,
                                      color: AppColors.secondaryDark,
                                    ),
                                  ),
                                )
                              : CustomCachedImage(
                                  imageUrl: photoPath,
                                  fit: BoxFit.cover,
                                ),
                          // Gradient & Angle Label
                          Container(
                            alignment: Alignment.bottomCenter,
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.maximize2,
                                  size: 10,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
                          AssessmentTranslations.t('no_scalp_photos', language),
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
    );
  }
}
