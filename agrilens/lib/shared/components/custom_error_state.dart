import 'package:agrilens/shared/components/custom_filled_btn.dart';
import 'package:agrilens/shared/components/custom_outlined_btn.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
// import 'package:solar_icon_pack/solar_icon_pack.dart';
import 'package:solar_icons/solar_icons.dart';

class CustomErrorState extends StatelessWidget {
  final VoidCallback? onRetry;
  const CustomErrorState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        // crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            SolarIconsOutline.dangerTriangle,
            color: AppColors.error,
            size: 48.0,
          ),
          const Gap(AppConstants.gapMedium),
          Text(
            'oops, Something went wrong.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(AppConstants.gapMedium),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomOutlinedButton(
                btnLabel: 'Cancel',
                onTap: () => context.pop(),
                expand: false,
              ),
              const Gap(AppConstants.gapMedium),
              CustomFilledButton(
                btnLabel: 'Try again',
                onTap: onRetry,
                expand: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
