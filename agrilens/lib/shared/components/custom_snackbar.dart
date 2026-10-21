import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';

class CustomSnackbar {
  final String message;
  final Color color;
  final SnackBarAction? action;
  final int? duration;

  const CustomSnackbar({
    required this.message,
    required this.color,
    this.action,
    this.duration,
  });

  void showSnackBar(BuildContext context) {
    if (!context.mounted) {
      return;
    }

    final brightness = Theme.of(context).brightness;
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? AppColors.white
            : AppColors.black;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: foregroundColor),
        ),
        backgroundColor: color,
        duration: Duration(seconds: duration ?? 3),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                brightness == Brightness.dark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        dismissDirection: DismissDirection.down,
        action: action,
      ),
    );
  }
}
