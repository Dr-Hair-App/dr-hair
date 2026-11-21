import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';

/// Clean, medical-grade reusable dropdown form field for Dr. Hair.
/// Supports both labeled inputs and placeholder-based dropdowns with
/// consistent borders and typography.
class AppDropdownFormField<T> extends StatelessWidget {
  final T? initialValue;
  final T? value;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? icon;
  final List<DropdownMenuItem<T>> items;
  final String? Function(T?)? validator;
  final ValueChanged<T?>? onChanged;
  final bool isBusy;
  final bool isDense;
  final Color? fillColor;
  final bool? filled;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final Color? dropdownColor;
  final TextStyle? style;

  const AppDropdownFormField({
    super.key,
    this.initialValue,
    this.value,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.icon,
    required this.items,
    this.validator,
    this.onChanged,
    this.isBusy = false,
    this.isDense = false,
    this.fillColor,
    this.filled,
    this.borderRadius,
    this.contentPadding,
    this.dropdownColor,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16);

    return DropdownButtonFormField<T>(
      initialValue: initialValue ?? value,
      items: items,
      validator: validator,
      onChanged: isBusy ? null : onChanged,
      isDense: isDense,
      icon: icon,
      dropdownColor: dropdownColor ?? Colors.white,
      style: style ??
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
          ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        filled: filled ?? (fillColor != null),
        fillColor: fillColor ?? Colors.white,
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.secondaryDark,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.secondaryDark,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(borderRadius: effectiveRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: effectiveRadius,
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
