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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingSmall,
        vertical: AppConstants.gapXSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showRetryAction)
            IconButton(
              onPressed: isBusy ? null : onRetryTap,
              tooltip: 'Retry response',
              icon: const Icon(SolarIconsOutline.refresh),
            ),
          if (isBusy)
            IconButton(
              onPressed: onCancelTap,
              tooltip: 'Cancel generation',
              icon: const Icon(SolarIconsOutline.closeCircle),
            ),
          IconButton(
            onPressed: isBusy ? null : onNewChatTap,
            tooltip: 'New chat',
            icon: const Icon(SolarIconsOutline.addCircle),
          ),
        ],
      ),
    );
  }
}
