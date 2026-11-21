import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../constants/app_colors.dart';

/// Standardized Dr. Hair Skeletonizer wrapper with clinical shimmer styling.
class AppSkeletonizer extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final Color? baseColor;
  final Color? highlightColor;

  const AppSkeletonizer({
    super.key,
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
  });

  static const ShimmerEffect defaultEffect = ShimmerEffect(
    baseColor: Color(0xFFF1F5F9),
    highlightColor: Color(0xFFFFFFFF),
    duration: Duration(milliseconds: 1400),
  );

  /// Helper to create a standardized rounded bone placeholder.
  static Widget bone({
    double? width,
    double? height,
    BorderRadius? borderRadius,
    BoxShape shape = BoxShape.rectangle,
    Color color = const Color(0xFFE2E8F0),
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(8))
            : null,
      ),
    );
  }

  /// Helper to create a pre-styled card bone placeholder matching [AppCard].
  static Widget cardBone({
    double? width,
    double height = 120,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: enabled,
      effect: ShimmerEffect(
        baseColor: baseColor ?? const Color(0xFFF1F5F9),
        highlightColor: highlightColor ?? const Color(0xFFFFFFFF),
        duration: const Duration(milliseconds: 1400),
      ),
      child: child,
    );
  }
}
