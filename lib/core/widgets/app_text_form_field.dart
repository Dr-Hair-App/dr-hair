import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';

/// Clean, medical-grade reusable text form field for Dr. Hair.
/// Supports both labeled inputs and standalone placeholder fields with
/// consistent borders, validation states, and typography.
class AppTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final int maxLines;
  final int? minLines;
  final bool expands;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final bool? filled;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final TextStyle? labelStyle;
  final BorderRadius? borderRadius;
  final Color? cursorColor;

  const AppTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.prefix,
    this.suffix,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onFieldSubmitted,
    this.onChanged,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.inputFormatters,
    this.contentPadding,
    this.fillColor,
    this.filled,
    this.style,
    this.hintStyle,
    this.labelStyle,
    this.borderRadius,
    this.cursorColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(16);

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      onTap: onTap,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      maxLines: expands ? null : maxLines,
      minLines: expands ? null : minLines,
      expands: expands,
      textAlign: textAlign,
      inputFormatters: inputFormatters,
      style: style ??
          const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDark,
          ),
      cursorColor: cursorColor ?? AppColors.primary,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        prefix: prefix,
        suffix: suffix,
        filled: filled ?? (fillColor != null),
        fillColor: fillColor ?? Colors.white,
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: hintStyle ??
            const TextStyle(
              fontSize: 14,
              color: AppColors.secondaryDark,
              fontWeight: FontWeight.w400,
            ),
        labelStyle: labelStyle ??
            const TextStyle(
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
