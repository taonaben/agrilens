import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';

class ChatStatusBanner extends StatelessWidget {
  const ChatStatusBanner({
    super.key,
    required this.message,
    required this.opacity,
  });

  final String message;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.gapXSmall,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingSmall,
          vertical: AppConstants.gapXSmall,
        ),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: colors.onErrorContainer),
            const SizedBox(width: AppConstants.gapSmall),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
