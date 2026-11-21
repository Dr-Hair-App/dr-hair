import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../constants/app_colors.dart';

/// Clean, medical-grade reusable toast notification system for Dr. Hair.
/// Shows floating, dismissible feedback pills above the current screen.
/// A new message replaces any visible or queued message so feedback never stacks.
class AppToast {
  AppToast._();

  static const Duration _defaultDuration = Duration(milliseconds: 2500);
  static const Duration _actionDuration = Duration(seconds: 4);

  /// Shows a custom [SnackBar] message through the standardized Dr. Hair toast styling.
  static void show(BuildContext context, SnackBar message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || !context.mounted) return;

    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();

    // SnackBar's own default duration is four seconds, so a newly constructed
    // SnackBar otherwise masks the shorter branded default for non-action
    // toasts. Preserve explicitly supplied durations and keep action toasts at
    // their accessible four-second default.
    final hasDefaultSnackBarDuration =
        message.duration == const Duration(seconds: 4);
    final duration = hasDefaultSnackBarDuration
        ? (message.action == null ? _defaultDuration : _actionDuration)
        : message.duration;

    messenger.showSnackBar(
      SnackBar(
        content: message.content,
        action: message.action,
        backgroundColor: message.backgroundColor ?? AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        showCloseIcon: false,
      ),
    );
  }

  /// Displays a success toast with a checkmark icon and subtle emerald/teal styling.
  static void showSuccess(
    BuildContext context,
    String message, {
    IconData icon = LucideIcons.checkCircle2,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = _defaultDuration,
  }) {
    HapticFeedback.lightImpact();
    _showBrandedToast(
      context: context,
      message: message,
      icon: icon,
      iconColor: const Color(0xFF34D399),
      backgroundColor: const Color(0xFF064E3B),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Displays an error or warning toast with an alert icon and red/danger styling.
  static void showError(
    BuildContext context,
    String message, {
    IconData icon = LucideIcons.alertCircle,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = _defaultDuration,
  }) {
    HapticFeedback.mediumImpact();
    _showBrandedToast(
      context: context,
      message: message,
      icon: icon,
      iconColor: const Color(0xFFF87171),
      backgroundColor: const Color(0xFF7F1D1D),
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Displays an informative or general status toast with primary branding.
  static void showInfo(
    BuildContext context,
    String message, {
    IconData icon = LucideIcons.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = _defaultDuration,
  }) {
    _showBrandedToast(
      context: context,
      message: message,
      icon: icon,
      iconColor: const Color(0xFF93C5FD),
      backgroundColor: AppColors.primaryDark,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// Helper to display a clean text message with optional icon and background.
  static void showText(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Color? iconColor,
    Duration duration = _defaultDuration,
  }) {
    _showBrandedToast(
      context: context,
      message: message,
      icon: icon,
      iconColor: iconColor,
      backgroundColor: backgroundColor ?? AppColors.primaryDark,
      duration: duration,
    );
  }

  static void _showBrandedToast({
    required BuildContext context,
    required String message,
    IconData? icon,
    Color? iconColor,
    required Color backgroundColor,
    String? actionLabel,
    VoidCallback? onAction,
    required Duration duration,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || !context.mounted) return;

    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: iconColor ?? Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: const Color(0xFF6EE7B7),
                onPressed: onAction,
              )
            : null,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        showCloseIcon: false,
      ),
    );
  }
}
