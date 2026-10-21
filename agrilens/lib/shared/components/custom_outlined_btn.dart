import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CustomOutlinedButton extends StatelessWidget {
  final String btnLabel;
  final VoidCallback? onTap;
  final bool expand;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final Widget? icon;
  final bool isDisabled;

  const CustomOutlinedButton({
    super.key,
    required this.btnLabel,
    this.onTap,
    this.expand = true,
    this.backgroundColor,
    this.textColor,
    this.isLoading = false,
    this.icon,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final foreground = textColor ?? AppColors.textPrimary(brightness);
    final disabledForeground = AppColors.textMuted(brightness);
    final disabledBackground =
        brightness == Brightness.dark ? AppColors.gray900 : AppColors.gray100;
    final disabledBorder =
        brightness == Brightness.dark ? AppColors.gray800 : AppColors.gray200;

    return SizedBox(
      width: expand ? double.infinity : null,
      height: 48,
      child: OutlinedButton(
        onPressed: isLoading || isDisabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.surface(brightness),
          disabledBackgroundColor:
              isLoading
                  ? backgroundColor ?? AppColors.surface(brightness)
                  : disabledBackground,
          foregroundColor: foreground,
          disabledForegroundColor:
              isLoading ? foreground : disabledForeground,
          side: BorderSide(color: AppColors.border(brightness)),
          disabledMouseCursor: SystemMouseCursors.basic,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled) && !isLoading) {
              return BorderSide(color: disabledBorder);
            }

            return BorderSide(color: AppColors.border(brightness));
          }),
        ),
        child:
            isLoading
                ? SizedBox.square(
                  dimension: 18,
                  child: CustomProgressIndicator(color: foreground),
                )
                : _OutlinedButtonContent(label: btnLabel, icon: icon),
      ),
    );
  }
}

class _OutlinedButtonContent extends StatelessWidget {
  final String label;
  final Widget? icon;

  const _OutlinedButtonContent({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon!,
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
