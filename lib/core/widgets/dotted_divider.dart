import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

/// A reusable, customizable dotted divider for clean visual separation.
///
/// Default dot size: height = 1.0, width = 3.0, spacing = 3.0.
class DottedDivider extends StatelessWidget {
  /// Total vertical height of the divider box (or width if vertical). Default is 20.
  final double height;

  /// Width of each individual dot/dash. Default is 3.0.
  final double dotWidth;

  /// Height/thickness of each individual dot/dash. Default is 1.0.
  final double dotHeight;

  /// Space between consecutive dots. Default is 3.0.
  final double spacing;

  /// Corner radius for each dot. If null, defaults to `dotHeight / 2` (rounded pill).
  final double? borderRadius;

  /// Color of the dots. Defaults to [AppColors.border] with 85% opacity.
  final Color? color;

  /// Optional padding around the divider.
  final EdgeInsetsGeometry? padding;

  /// Orientation of the divider. Default is [Axis.horizontal].
  final Axis axis;

  const DottedDivider({
    super.key,
    this.height = 20,
    this.dotWidth = 3.0,
    this.dotHeight = 1.0,
    this.spacing = 3.0,
    this.borderRadius,
    this.color,
    this.padding,
    this.axis = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.border.withValues(alpha: 0.85);

    Widget divider = SizedBox(
      height: axis == Axis.horizontal ? height : null,
      width: axis == Axis.vertical ? height : null,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableLength = axis == Axis.horizontal
                ? constraints.maxWidth
                : constraints.maxHeight;

            if (availableLength <= 0 || !availableLength.isFinite) {
              return const SizedBox.shrink();
            }

            return CustomPaint(
              size: axis == Axis.horizontal
                  ? Size(availableLength, dotHeight)
                  : Size(dotHeight, availableLength),
              painter: _DottedDividerPainter(
                color: effectiveColor,
                dotWidth: dotWidth,
                dotHeight: dotHeight,
                spacing: spacing,
                borderRadius: borderRadius ?? (dotHeight / 2),
                axis: axis,
              ),
            );
          },
        ),
      ),
    );

    if (padding != null) {
      divider = Padding(padding: padding!, child: divider);
    }

    return divider;
  }
}

class _DottedDividerPainter extends CustomPainter {
  final Color color;
  final double dotWidth;
  final double dotHeight;
  final double spacing;
  final double borderRadius;
  final Axis axis;

  const _DottedDividerPainter({
    required this.color,
    required this.dotWidth,
    required this.dotHeight,
    required this.spacing,
    required this.borderRadius,
    required this.axis,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    final primaryLength = axis == Axis.horizontal ? size.width : size.height;
    final step = dotWidth + spacing;
    if (step <= 0) return;

    final totalDots = (primaryLength / step).floor();
    if (totalDots <= 0) return;

    final usedLength = (totalDots - 1) * step + dotWidth;
    double start = (primaryLength - usedLength) / 2;

    if (axis == Axis.horizontal) {
      final centerY = size.height / 2;
      for (int i = 0; i < totalDots; i++) {
        final rect = Rect.fromLTWH(
          start,
          centerY - (dotHeight / 2),
          dotWidth,
          dotHeight,
        );
        if (borderRadius > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
        start += step;
      }
    } else {
      final centerX = size.width / 2;
      for (int i = 0; i < totalDots; i++) {
        final rect = Rect.fromLTWH(
          centerX - (dotHeight / 2),
          start,
          dotHeight,
          dotWidth,
        );
        if (borderRadius > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
            paint,
          );
        } else {
          canvas.drawRect(rect, paint);
        }
        start += step;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedDividerPainter oldDelegate) =>
      color != oldDelegate.color ||
      dotWidth != oldDelegate.dotWidth ||
      dotHeight != oldDelegate.dotHeight ||
      spacing != oldDelegate.spacing ||
      borderRadius != oldDelegate.borderRadius ||
      axis != oldDelegate.axis;
}

/// A container widget that wraps its [child] with a customizable dotted/dashed border.
///
/// Default dot size: strokeWidth/height = 1.0, dotWidth = 3.0, spacing = 3.0.
class DottedBorder extends StatelessWidget {
  /// The widget inside the dotted border.
  final Widget child;

  /// Width/length of each dot along the border line. Default is 3.0.
  final double dotWidth;

  /// Thickness of the border line. Default is 1.0.
  final double strokeWidth;

  /// Gap between consecutive dots. Default is 3.0.
  final double spacing;

  /// Corner radius of the rounded border. Default is 12.0.
  final double radius;

  /// Color of the dotted border. Defaults to [AppColors.border].
  final Color? color;

  /// Inner padding inside the border. Default is [EdgeInsets.zero].
  final EdgeInsetsGeometry padding;

  const DottedBorder({
    super.key,
    required this.child,
    this.dotWidth = 3.0,
    this.strokeWidth = 1.0,
    this.spacing = 3.0,
    this.radius = 12.0,
    this.color,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.border.withValues(alpha: 0.85);

    return CustomPaint(
      foregroundPainter: _DottedBorderPainter(
        color: effectiveColor,
        dotWidth: dotWidth,
        strokeWidth: strokeWidth,
        spacing: spacing,
        radius: radius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double dotWidth;
  final double strokeWidth;
  final double spacing;
  final double radius;

  const _DottedBorderPainter({
    required this.color,
    required this.dotWidth,
    required this.strokeWidth,
    required this.spacing,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final path = Path();
    if (radius > 0) {
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    } else {
      path.addRect(rect);
    }

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = (distance + dotWidth <= metric.length)
            ? dotWidth
            : metric.length - distance;
        dashPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dotWidth + spacing;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) =>
      color != oldDelegate.color ||
      dotWidth != oldDelegate.dotWidth ||
      strokeWidth != oldDelegate.strokeWidth ||
      spacing != oldDelegate.spacing ||
      radius != oldDelegate.radius;
}

