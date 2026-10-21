import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';

class CustomDropdownFormField extends StatelessWidget {
  const CustomDropdownFormField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.labelText,
    this.labelTextColor,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.isExpanded = true,
    this.enabled = true,
  });

  final List<DropdownMenuItem<String>> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? labelText;
  final Color? labelTextColor;
  final String? hintText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isExpanded;
  final bool enabled;

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
    final mutedColor = AppColors.textMuted(brightness);
    final borderColor = AppColors.border(brightness);

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.paddingSmall),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: validator,
        isExpanded: isExpanded,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary(brightness),
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.surfaceAlt(brightness),
          hintText: hintText,
          labelText: labelText,
          labelStyle: theme.textTheme.bodyMedium?.copyWith(
            color: labelTextColor ?? mutedColor,
          ),
          floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          helperText: helperText,
          helperMaxLines: 2,
          helperStyle: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
          errorMaxLines: 2,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
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
        dropdownColor: AppColors.surfaceRaised(brightness),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
      ),
    );
  }
}
