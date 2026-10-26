import 'package:agrilens/app/chat/components/widgets/message_bubble.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:agrilens/app/chat/models/prediction.dart';
import 'package:agrilens/app/chat/services/remote_chat_service.dart';
import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.isLoading,
    required this.messages,
    required this.predictionsByMessageId,
    this.controller,
    this.answersByMessageId = const {},
  });

  final bool isLoading;
  final List<MessageModel> messages;
  final Map<String, Prediction> predictionsByMessageId;
  final ScrollController? controller;
  final Map<String, AnswerMetadata> answersByMessageId;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CustomProgressIndicator());
    }

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingXLarge),
          child: Text(
            'Ask a maize or tomato crop-care question, or share a leaf photo for a possible condition match.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final chronologicalIndex = messages.length - 1 - index;
        final message = messages[chronologicalIndex];
        return MessageBubble(
          message: message,
          prediction: predictionsByMessageId[message.id],
          answerMetadata: answersByMessageId[message.id],
        );
      },
    );
  }
}
