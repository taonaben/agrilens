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
    required this.onReplaceTap,
  });

  final String imagePath;
  final bool isBusy;
  final VoidCallback onClearTap;
  final VoidCallback onReplaceTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingMedium,
        AppConstants.paddingSmall,
        AppConstants.paddingMedium,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            InkWell(
              onTap: () => _openPreview(context),
              borderRadius: BorderRadius.circular(
                AppConstants.borderRadiusMedium,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppConstants.borderRadiusMedium,
                ),
                child: Image.file(
                  File(imagePath),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.surfaceAlt(brightness),
                        alignment: Alignment.center,
                        child: const Icon(SolarIconsOutline.gallery),
                      ),
                ),
              ),
            ),
            const Gap(AppConstants.gapSmall),
            Text('Photo ready', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            IconButton(
              tooltip: 'Remove photo',
              onPressed: isBusy ? null : onClearTap,
              icon: const Icon(SolarIconsOutline.closeCircle),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPreview(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder:
          (dialogContext) => Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Close preview',
                      color: Colors.white,
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(SolarIconsOutline.closeCircle),
                    ),
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      child: Center(
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) => const Text(
                                'Could not preview image',
                                style: TextStyle(color: Colors.white),
                              ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingLarge),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              isBusy
                                  ? null
                                  : () {
                                    Navigator.pop(dialogContext);
                                    onReplaceTap();
                                  },
                          icon: const Icon(SolarIconsOutline.refresh),
                          label: const Text('Replace'),
                        ),
                        const Gap(AppConstants.gapMedium),
                        FilledButton.tonalIcon(
                          onPressed:
                              isBusy
                                  ? null
                                  : () {
                                    Navigator.pop(dialogContext);
                                    onClearTap();
                                  },
                          icon: const Icon(SolarIconsOutline.trashBinTrash),
                          label: const Text('Remove'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
