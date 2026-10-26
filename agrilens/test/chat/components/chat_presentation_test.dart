import 'package:agrilens/app/chat/components/widgets/message_bubble.dart';
import 'package:agrilens/app/chat/components/widgets/chat_message_list.dart';
import 'package:agrilens/app/chat/components/widgets/pending_image_preview_card.dart';
import 'package:agrilens/app/chat/models/message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MessageModel _message({required MessageRole role, required String text}) {
  final now = DateTime(2026, 10, 24);
  return MessageModel(
    id: text,
    conversationId: 'conversation',
    role: role,
    contentType: MessageContentType.text,
    textContent: text,
    lifecycle: MessageLifecycle.complete,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('empty chat explains text-only and photo options', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            isLoading: false,
            messages: [],
            predictionsByMessageId: {},
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Ask a maize or tomato question'),
      findsOneWidget,
    );
    expect(find.textContaining('share a leaf photo'), findsOneWidget);
  });

  testWidgets('user messages align right and assistant messages align left', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MessageBubble(
                message: _message(role: MessageRole.user, text: 'Question'),
              ),
              MessageBubble(
                message: _message(role: MessageRole.assistant, text: 'Answer'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getCenter(find.text('Question')).dx,
      greaterThan(tester.getCenter(find.text('Answer')).dx),
    );
  });

  testWidgets('message alignment fits a narrow dark chat layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Column(
            children: [
              MessageBubble(
                message: _message(role: MessageRole.user, text: 'Question'),
              ),
              MessageBubble(
                message: _message(role: MessageRole.assistant, text: 'Answer'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.text('Question')).dx,
      greaterThan(tester.getCenter(find.text('Answer')).dx),
    );
  });

  testWidgets('attachment preview offers replace and remove actions', (
    tester,
  ) async {
    var removed = false;
    var replaced = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingImagePreviewCard(
            imagePath: 'missing-image.jpg',
            isBusy: false,
            onClearTap: () => removed = true,
            onReplaceTap: () => replaced = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Remove photo'));
    expect(removed, isTrue);
    removed = false;

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(replaced, isTrue);

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
  });
}
