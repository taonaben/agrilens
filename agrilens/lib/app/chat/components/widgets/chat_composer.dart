import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:solar_icons/solar_icons.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.isBusy,
    required this.hasPendingImage,
    this.attachmentPreview,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isBusy;
  final bool hasPendingImage;
  final Widget? attachmentPreview;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          border: Border(top: BorderSide(color: AppColors.border(brightness))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachmentPreview != null) attachmentPreview!,
            Row(
              children: [
                IconButton(
                  onPressed: isBusy ? null : onCameraTap,
                  icon: const Icon(SolarIconsOutline.camera),
                  tooltip: 'Take photo',
                ),
                IconButton(
                  onPressed: isBusy ? null : onGalleryTap,
                  icon: const Icon(SolarIconsOutline.gallery),
                  tooltip: 'Select from gallery',
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isBusy,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (!isBusy) {
                        onSend();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Message',
                      filled: true,
                      fillColor: AppColors.surfaceAlt(brightness),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingMedium,
                        vertical: AppConstants.paddingSmall,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                          color: AppColors.border(brightness),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                          color: AppColors.border(brightness),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(AppConstants.gapSmall),
                IconButton.filled(
                  onPressed: isBusy ? null : onSend,
                  icon: const Icon(SolarIconsOutline.arrowRight),
                  tooltip:
                      hasPendingImage
                          ? 'Send image for diagnosis'
                          : 'Send message',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
