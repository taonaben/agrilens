import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextfield extends StatelessWidget {
  final String? hintText;
  final String? labelText;
  final Color? labelTextColor;
  final String? helperText;
  final String? errorText;
  final int maxLines;
  final int? maxLength;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;

  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixWidget;
  final Widget? prefixWidget;
  final Function(String)? onFieldSubmitted;
  final bool obscureText;
  final bool readOnly;
  final int minLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  const CustomTextfield({
    super.key,
    this.hintText,
    this.labelText,
    this.labelTextColor,
    this.helperText,
    this.errorText,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.controller,
    this.onChanged,
    this.focusNode,
    this.validator,
    this.inputFormatters,
    this.suffixWidget,
    this.prefixWidget,
    this.onFieldSubmitted,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  InputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final textColor = labelTextColor ?? AppColors.textPrimary(brightness);
    final mutedColor = AppColors.textMuted(brightness);
    final borderColor = AppColors.border(brightness);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction ?? TextInputAction.next,
      textCapitalization: textCapitalization,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      maxLength: maxLength,
      obscureText: obscureText,
      readOnly: readOnly,
      enabled: enabled,
      onChanged: onChanged,

      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      inputFormatters: inputFormatters,
      cursorColor: AppColors.primary,
      style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surfaceAlt(brightness),
        hintText: hintText,
        labelText: labelText,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
        floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
        helperText: helperText,
        helperMaxLines: 2,
        helperStyle: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
        errorText: errorText,
        errorMaxLines: 2,
        suffixIcon: suffixWidget,
        prefixIcon: prefixWidget,
        prefixIconColor: mutedColor,
        suffixIconColor: mutedColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingLarge,
          vertical: 14,
        ),
        border: _border(borderColor),
        enabledBorder: _border(borderColor),
        disabledBorder: _border(AppColors.divider(brightness)),
        focusedBorder: _border(AppColors.primary, width: 1.4),
        errorBorder: _border(theme.colorScheme.error),
        focusedErrorBorder: _border(theme.colorScheme.error, width: 1.4),
      ),
    );
  }
}
