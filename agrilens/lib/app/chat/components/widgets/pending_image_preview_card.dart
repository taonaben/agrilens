import 'dart:io';

import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:solar_icons/solar_icons.dart';

class PendingImagePreviewCard extends StatelessWidget {
  const PendingImagePreviewCard({
    super.key,
    required this.imagePath,
    required this.isBusy,
    required this.onClearTap,
  });

  final String imagePath;
  final bool isBusy;
  final VoidCallback onClearTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(brightness),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image ready to send',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap(AppConstants.gapSmall),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              AppConstants.borderRadiusMedium,
            ),
            child: Image.file(
              File(imagePath),
              height: 180,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) => const SizedBox(
                    height: 140,
                    child: Center(child: Text('Could not preview image')),
                  ),
            ),
          ),
          const Gap(AppConstants.gapSmall),
          Wrap(
            spacing: AppConstants.gapSmall,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onClearTap,
                icon: const Icon(SolarIconsOutline.trashBinTrash),
                label: const Text('Remove image'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
