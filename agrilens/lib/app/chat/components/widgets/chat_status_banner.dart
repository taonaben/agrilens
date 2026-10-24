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
    return Container(
      width: double.infinity,
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: opacity),
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
