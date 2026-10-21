import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class CustomProgressIndicator extends StatelessWidget {
  final double? size;
  final Color? color;

  const CustomProgressIndicator({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    return LoadingAnimationWidget.waveDots(
      color: color ?? AppColors.primary,
      size: size ?? AppConstants.progressIndicatorSizeMedium,
    );
  }
}
