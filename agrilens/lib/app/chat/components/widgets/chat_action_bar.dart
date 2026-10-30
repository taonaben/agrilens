import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class ChatActionBar extends StatelessWidget {
  const ChatActionBar({
    super.key,
    required this.isBusy,
    required this.showRetryAction,
    required this.onNewChatTap,
    required this.onRetryTap,
    required this.onDeleteTap,
    required this.onCancelTap,
    required this.responseLanguage,
    required this.onResponseLanguageChanged,
  });

  final bool isBusy;
  final bool showRetryAction;
  final VoidCallback onNewChatTap;
  final VoidCallback onRetryTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onCancelTap;
  final String responseLanguage;
  final ValueChanged<String> onResponseLanguageChanged;

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
          _ResponseLanguageMenu(
            value: responseLanguage,
            enabled: !isBusy,
            onSelected: onResponseLanguageChanged,
          ),
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
            onPressed: isBusy ? null : onDeleteTap,
            tooltip: 'Delete conversation',
            icon: const Icon(SolarIconsOutline.trashBinTrash),
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

class _ResponseLanguageMenu extends StatelessWidget {
  const _ResponseLanguageMenu({
    required this.value,
    required this.enabled,
    required this.onSelected,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onSelected;

  static const _languages = {
    'english': 'English',
    'shona': 'Shona',
    'ndebele': 'Ndebele',
  };

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final label = _languages[value] ?? 'English';

    return PopupMenuButton<String>(
      tooltip: 'Reply language',
      enabled: enabled,
      initialValue: value,
      onSelected: onSelected,
      color: AppColors.surface(brightness),
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder:
          (context) => [
            for (final entry in _languages.entries)
              PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    Expanded(child: Text(entry.value)),
                    if (entry.key == value)
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
          ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt(brightness),
          border: Border.all(color: AppColors.border(brightness)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textMuted(brightness),
            ),
          ],
        ),
      ),
    );
  }
}
