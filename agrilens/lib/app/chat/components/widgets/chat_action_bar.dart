import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class ChatActionBar extends StatelessWidget {
  const ChatActionBar({
    super.key,
    required this.isBusy,
    required this.showRetryAction,
    required this.onNewChatTap,
    required this.onRetryTap,
    required this.onCancelTap,
  });

  final bool isBusy;
  final bool showRetryAction;
  final VoidCallback onNewChatTap;
  final VoidCallback onRetryTap;
  final VoidCallback onCancelTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        border: Border(bottom: BorderSide(color: AppColors.border(brightness))),
      ),
      child: Wrap(
        spacing: AppConstants.gapSmall,
        runSpacing: AppConstants.gapSmall,
        children: [
          OutlinedButton.icon(
            onPressed: isBusy ? null : onNewChatTap,
            icon: const Icon(SolarIconsOutline.addCircle),
            label: const Text('New chat'),
          ),
          if (showRetryAction)
            OutlinedButton.icon(
              onPressed: isBusy ? null : onRetryTap,
              icon: const Icon(SolarIconsOutline.refresh),
              label: const Text('Retry response'),
            ),
          if (isBusy)
            OutlinedButton.icon(
              onPressed: onCancelTap,
              icon: const Icon(SolarIconsOutline.closeCircle),
              label: const Text('Cancel'),
            ),
        ],
      ),
    );
  }
}
