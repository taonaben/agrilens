import 'dart:io';

import 'package:agrilens/app/chat/components/widgets/prediction_card.dart';
import 'package:agrilens/app/chat/components/widgets/suggested_product_card.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gap/gap.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/remote_chat_service.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.prediction,
    this.answerMetadata,
  });

  final MessageModel message;
  final Prediction? prediction;
  final AnswerMetadata? answerMetadata;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final brightness = Theme.of(context).brightness;
    final bubbleColor =
        isUser
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
            : AppColors.surfaceAlt(brightness);

    if (message.contentType == MessageContentType.image) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.gapSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width < 600 ? 260 : 340,
                ),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: _attachedImage(context, message),
                ),
              ),
            ),
            if (prediction != null) ...[
              const Gap(AppConstants.gapSmall),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        MediaQuery.sizeOf(context).width < 600 ? 320 : 560,
                  ),
                  child: PredictionCard(prediction: prediction!),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 600 ? 320 : 620,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppConstants.gapSmall),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall,
          ),
          decoration: BoxDecoration(
            color: isUser ? bubbleColor : AppColors.surfaceRaised(brightness),
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            border:
                isUser ? null : Border.all(color: AppColors.border(brightness)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.contentType == MessageContentType.text &&
                  (message.textContent?.trim().isNotEmpty ?? false))
                if (isUser)
                  Text(message.textContent!.trim())
                else
                  MarkdownBody(
                    data: message.textContent!.trim(),
                    styleSheet: MarkdownStyleSheet.fromTheme(
                      Theme.of(context),
                    ).copyWith(
                      p: Theme.of(context).textTheme.bodyMedium,
                      h1: Theme.of(context).textTheme.titleLarge,
                      h2: Theme.of(context).textTheme.titleMedium,
                      h3: Theme.of(context).textTheme.titleSmall,
                      listBullet: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              if (prediction != null) ...[
                const Gap(AppConstants.gapSmall),
                PredictionCard(prediction: prediction!),
              ],
              if (answerMetadata != null &&
                  (answerMetadata!.sources.isNotEmpty ||
                      answerMetadata!.products.isNotEmpty)) ...[
                const Gap(AppConstants.gapSmall),
                if (answerMetadata!.sources.isNotEmpty)
                  ...answerMetadata!.sources.map(
                    (source) => TextButton.icon(
                      onPressed: () => _openUrl(source.url),
                      icon: const Icon(SolarIconsOutline.link, size: 16),
                      label: Text(
                        '${source.title}${source.organization.isEmpty ? '' : ' · ${source.organization}'}',
                      ),
                    ),
                  ),
                for (final product in answerMetadata!.products)
                  SuggestedProductCard(suggestion: product),
              ],
              if (message.lifecycle == MessageLifecycle.pending) ...[
                const Gap(AppConstants.gapSmall),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomProgressIndicator(size: 18),
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

  Widget _attachedImage(BuildContext context, MessageModel imageMessage) {
    final path = imageMessage.localImagePath;
    if (path == null) return const Text('Leaf image unavailable');
    return GestureDetector(
      onTap: () => _showImagePreview(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 0.92,
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  color: AppColors.surfaceAlt(Theme.of(context).brightness),
                  alignment: Alignment.center,
                  child: const Text('Image unavailable'),
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showImagePreview(BuildContext context, String imagePath) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder:
          (context) => Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'Close image',
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
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
                                'Image unavailable',
                                style: TextStyle(color: Colors.white),
                              ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.paddingLarge),
                ],
              ),
            ),
          ),
    );
  }
}
