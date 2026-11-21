import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

/// Clean, medical-grade reusable card container for Dr. Hair.
/// Encapsulates consistent 18-20px rounded corners, subtle shadows,
/// border treatments, and optional touch feedback / ink ripples.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;
  final Clip clipBehavior;
  final bool isSelected;
  final Color? selectedBorderColor;
  final Color? splashColor;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.boxShadow,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
    this.isSelected = false,
    this.selectedBorderColor,
    this.splashColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(18);
    final effectiveBorderColor = isSelected
        ? (selectedBorderColor ?? AppColors.primary)
        : (borderColor ?? AppColors.border);

    final defaultShadow = [
      const BoxShadow(
        color: Color(0x080F172A),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ];

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: effectiveBorderColor,
          width: isSelected ? (borderWidth < 1.5 ? 1.5 : borderWidth) : borderWidth,
        ),
        boxShadow: boxShadow ?? defaultShadow,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        clipBehavior: clipBehavior,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: effectiveRadius,
          splashColor: splashColor ?? AppColors.primary5,
          highlightColor: AppColors.primary5.withValues(alpha: 0.5),
          child: content,
        ),
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    return content;
  }
}
