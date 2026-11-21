import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';

class ClinicalReportCard extends StatelessWidget {
  final String title;
  final String fileName;
  final String fileSize;
  final String uploadedBy;
  final String uploadDate;
  final String? subtitle;
  final bool isNew;
  final bool isLoading;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onTap;

  const ClinicalReportCard({
    super.key,
    required this.title,
    required this.fileName,
    required this.fileSize,
    required this.uploadedBy,
    required this.uploadDate,
    required this.onTap,
    this.isNew = false,
    this.isLoading = false,
    this.subtitle,
    this.actionLabel = 'Open report',
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, badge) = _fileStyle(fileName);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isNew ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            // border: Border.all(
            //   color: isNew ? const Color(0xFF0D9488) : AppColors.border,
            //   width: isNew ? 1 : 1.0,
            // ),
            // boxShadow: [
            //   BoxShadow(
            //     color: isNew
            //         ? const Color(0x140D9488)
            //         : const Color(0x080F172A),
            //     blurRadius: 14,
            //     offset: const Offset(0, 5),
            //   ),
            // ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [_badge(badge, color)],
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF0D9488)
                                    .withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0D9488),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0D9488),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryDark,
                            ),
                          ),
                        ),
                        if (fileSize.trim().isNotEmpty) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryDark,
                            ),
                          ),
                          Text(
                            fileSize,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (uploadedBy.trim().isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              uploadedBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.secondaryDark,
                              ),
                            ),
                          ),
                          if (uploadDate.trim().isNotEmpty)
                            const Text(
                              ' · ',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.secondaryDark,
                              ),
                            ),
                        ],
                        if (uploadDate.trim().isNotEmpty) ...[
                          const Icon(
                            LucideIcons.calendar,
                            size: 10,
                            color: AppColors.secondaryDark,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              uploadDate.toLowerCase().contains('received')
                                  ? uploadDate
                                  : 'Received: $uploadDate',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: actionLabel,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary5,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          actionIcon ?? LucideIcons.download,
                          color: AppColors.primary,
                          size: 17,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.35,
      ),
    ),
  );

  (IconData, Color, String) _fileStyle(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') {
      return (LucideIcons.fileText, const Color(0xFFDC2626), 'PDF');
    }
    if ({'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}.contains(ext)) {
      return (LucideIcons.fileText, const Color(0xFF0D9488), 'IMAGE');
    }
    if ({'xls', 'xlsx', 'xlsm', 'csv', 'tsv'}.contains(ext)) {
      return (LucideIcons.table, const Color(0xFF16803C), 'SHEET');
    }
    if ({'ppt', 'pptx', 'pptm'}.contains(ext)) {
      return (LucideIcons.presentation, const Color(0xFFEA580C), 'SLIDES');
    }
    if (ext == 'txt' || ext == 'rtf') {
      return (LucideIcons.fileText, const Color(0xFF475569), 'TEXT');
    }
    return (LucideIcons.fileText, const Color(0xFF2563EB), 'DOCUMENT');
  }
}
