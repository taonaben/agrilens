import 'dart:io';

import 'package:agrilens/app/chat/components/widgets/prediction_card.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.prediction});

  final MessageModel message;
  final Prediction? prediction;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final brightness = Theme.of(context).brightness;
    final bubbleColor =
        isUser
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : AppColors.surfaceAlt(brightness);
    final borderColor =
        isUser
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
            : AppColors.border(brightness);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppConstants.gapXSmall),
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.contentType == MessageContentType.image &&
                  message.localImagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppConstants.borderRadiusMedium,
                  ),
                  child: Image.file(
                    File(message.localImagePath!),
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          height: 120,
                          color: AppColors.surfaceAlt(brightness),
                          alignment: Alignment.center,
                          child: const Text('Image unavailable'),
                        ),
                  ),
                ),
              if (message.contentType == MessageContentType.text &&
                  (message.textContent?.trim().isNotEmpty ?? false))
                Text(message.textContent!.trim()),
              if (prediction != null) ...[
                const Gap(AppConstants.gapSmall),
                PredictionCard(prediction: prediction!),
              ],
              if (message.lifecycle == MessageLifecycle.pending) ...[
                const Gap(AppConstants.gapSmall),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    Gap(8),
                    Text('Processing...'),
                  ],
                ),
              ],
              if (message.lifecycle == MessageLifecycle.failed &&
                  message.failureReason != null) ...[
                const Gap(AppConstants.gapSmall),
                Text(
                  message.failureReason!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
