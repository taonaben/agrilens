import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CustomFilledButton extends StatelessWidget {
  final String btnLabel;
  final Widget? btnWidget;
  final VoidCallback? onTap;
  final bool expand;
  final Color? backgroundColor;
  final Color? textColor;
  final bool isLoading;
  final Widget? icon;
  final bool isDisabled;

  const CustomFilledButton({
    super.key,
    required this.btnLabel,
    this.btnWidget,
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
    final foreground = textColor ?? AppColors.onPrimary;
    final disabledBackground = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.12);
    final disabledForeground =
        brightness == Brightness.dark ? AppColors.gray500 : AppColors.gray400;
    final child =
        btnWidget ??
        _ButtonContent(
          label: btnLabel,
          icon: icon,
          isLoading: isLoading,
          progressColor: isDisabled ? disabledForeground : foreground,
        );

    return SizedBox(
      width: expand ? double.infinity : null,
      height: 48,

      child: FilledButton(
        onPressed: isLoading || isDisabled ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          disabledBackgroundColor:
              isLoading
                  ? backgroundColor ?? AppColors.primary
                  : disabledBackground,
          foregroundColor: foreground,
          disabledForegroundColor: isLoading ? foreground : disabledForeground,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isLoading;
  final Color progressColor;

  const _ButtonContent({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox.square(
        dimension: 18,
        child: CustomProgressIndicator(color: progressColor),
      );
    }

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
