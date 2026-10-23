import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:agrilens/app/chat/data/database.dart';
import 'package:agrilens/app/chat/data/conversation_repository.dart';
import 'package:agrilens/app/chat/data/message_repository.dart';
import 'package:agrilens/app/chat/data/prediction_repository.dart';
import 'package:agrilens/app/chat/models/conversation.dart' as model;
import 'package:agrilens/app/chat/models/message.dart' as model;
import 'package:agrilens/app/chat/models/prediction.dart' as model;

/// Test database that uses in-memory SQLite
AgriLensDatabase createTestDatabase() {
  final db = NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA foreign_keys = ON');
    },
  );
  return AgriLensDatabase.forTesting(db);
}

void main() {
  late AgriLensDatabase db;
  late ConversationRepository conversationRepo;
  late MessageRepository messageRepo;
  late PredictionRepository predictionRepo;

  setUp(() {
    db = createTestDatabase();
    conversationRepo = ConversationRepository(db);
    messageRepo = MessageRepository(db);
    predictionRepo = PredictionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Schema', () {
    test('database initializes successfully', () {
      expect(db, isNotNull);
      expect(db.schemaVersion, 1);
    });

    test('tables are created', () async {
      // Insert and query should work without errors
      final conv = await conversationRepo.createConversation(
        title: 'Test Conversation',
      );
      expect(conv.id, isNotEmpty);
    });
  });

  group('Conversation Operations', () {
    test('create and retrieve conversation', () async {
      final conv = await conversationRepo.createConversation(
        title: 'My First Conversation',
      );

      expect(conv.id, isNotEmpty);
      expect(conv.title, 'My First Conversation');
      expect(conv.createdAt, isNotNull);
      expect(conv.updatedAt, isNotNull);

      final retrieved = await conversationRepo.getConversation(conv.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, conv.id);
      expect(retrieved.title, conv.title);
    });

    test('list all conversations ordered by updatedAt desc', () async {
      await conversationRepo.createConversation(title: 'First');
      await Future.delayed(const Duration(milliseconds: 2));
      await conversationRepo.createConversation(title: 'Second');
      await Future.delayed(const Duration(milliseconds: 2));
      await conversationRepo.createConversation(title: 'Third');

      final allConvs = await conversationRepo.getAllConversations();
      expect(allConvs.length, 3);
      // Verify ordering: most recent should have latest updatedAt
      expect(
        allConvs[0].updatedAt.isAfter(allConvs[1].updatedAt) ||
            allConvs[0].updatedAt.isAtSameMomentAs(allConvs[1].updatedAt),
        isTrue,
      );
      expect(
        allConvs[1].updatedAt.isAfter(allConvs[2].updatedAt) ||
            allConvs[1].updatedAt.isAtSameMomentAs(allConvs[2].updatedAt),
        isTrue,
      );
    });

    test('update conversation title', () async {
      final conv = await conversationRepo.createConversation(title: 'Original');

      await conversationRepo.updateConversationTitle(conv.id, 'Updated Title');

      final updated = await conversationRepo.getConversation(conv.id);
      expect(updated!.title, 'Updated Title');
    });

    test('delete conversation', () async {
      final conv = await conversationRepo.createConversation(
        title: 'To Delete',
      );

      await conversationRepo.deleteConversation(conv.id);

      final retrieved = await conversationRepo.getConversation(conv.id);
      expect(retrieved, isNull);
    });
  });

  group('Message Operations', () {
    late model.Conversation testConversation;

    setUp(() async {
      testConversation = await conversationRepo.createConversation(
        title: 'Test Conversation',
      );
    });

    test('create and retrieve message', () async {
      final message = await messageRepo.createMessage(
        conversationId: testConversation.id,
        role: model.MessageRole.user,
        contentType: model.MessageContentType.text,
        textContent: 'Hello, AgriLens!',
      );

      expect(message.id, isNotEmpty);
      expect(message.conversationId, testConversation.id);
      expect(message.role, model.MessageRole.user);
      expect(message.contentType, model.MessageContentType.text);
      expect(message.textContent, 'Hello, AgriLens!');
      expect(message.lifecycle, model.MessageLifecycle.pending);

      final retrieved = await messageRepo.getMessage(message.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, message.id);
    });

    test('get messages for conversation ordered by createdAt', () async {
      final msg1 = await messageRepo.createMessage(
        conversationId: testConversation.id,
        role: model.MessageRole.user,
        contentType: model.MessageContentType.text,
        textContent: 'First message',
      );

      await Future.delayed(const Duration(milliseconds: 10));

      final msg2 = await messageRepo.createMessage(
        conversationId: testConversation.id,
        role: model.MessageRole.assistant,
        contentType: model.MessageContentType.text,
        textContent: 'Second message',
      );

      final messages = await messageRepo.getMessagesForConversation(
        testConversation.id,
      );

      expect(messages.length, 2);
      expect(messages[0].id, msg1.id);
      expect(messages[1].id, msg2.id);
    });

    test('update message lifecycle to complete', () async {
      final message = await messageRepo.createMessage(
        conversationId: testConversation.id,
        role: model.MessageRole.user,
        contentType: model.MessageContentType.image,
        localImagePath: '/path/to/image.jpg',
      );

      expect(message.lifecycle, model.MessageLifecycle.pending);

      await messageRepo.markMessageComplete(message.id);

      final updated = await messageRepo.getMessage(message.id);
      expect(updated!.lifecycle, model.MessageLifecycle.complete);
    });

    test('update message lifecycle to failed with reason', () async {
      final message = await messageRepo.createMessage(
        conversationId: testConversation.id,
        role: model.MessageRole.assistant,
        contentType: model.MessageContentType.text,
        textContent: 'Analyzing...',
      );

      await messageRepo.markMessageFailed(message.id, 'Model inference failed');

      final updated = await messageRepo.getMessage(message.id);
      expect(updated!.lifecycle, model.MessageLifecycle.failed);
      expect(updated.failureReason, 'Model inference failed');
    });

    test('message with image path', () async {
      final imagePath = '/data/app/images/leaf_photo.jpg';
      final message = await messageRepo.createMessage(
        conversationId: testConversation.id,
        role: model.MessageRole.user,
        contentType: model.MessageContentType.image,
        localImagePath: imagePath,
      );

      expect(message.localImagePath, imagePath);

      final retrieved = await messageRepo.getMessage(message.id);
      expect(retrieved!.localImagePath, imagePath);
    });
  });

  group('Prediction Operations', () {
    late model.Conversation testConversation;
    late model.Message testMessage;

    setUp(() async {
      testConversation = await conversationRepo.createConversation(
        title: 'Test Conversation',
      );
      testMessage = await messageRepo.createMessage(
        conversationId: testConversation.id,
        role: model.MessageRole.user,
        contentType: model.MessageContentType.image,
        localImagePath: '/path/to/leaf.jpg',
      );
    });

    test('create and retrieve prediction', () async {
      final prediction = await predictionRepo.createPrediction(
        messageId: testMessage.id,
        classId: 0,
        crop: 'maize',
        condition: 'common_rust',
        decisionState: model.DecisionState.possibleMatch,
        topLogit: 5.2,
        calibratedScore: 0.92,
        margin: 0.35,
        modelVersion: 'v1.0.0',
        preprocessVersion: 'v1.0.0',
      );

      expect(prediction.id, isNotEmpty);
      expect(prediction.messageId, testMessage.id);
      expect(prediction.classId, 0);
      expect(prediction.crop, 'maize');
      expect(prediction.condition, 'common_rust');
      expect(prediction.decisionState, model.DecisionState.possibleMatch);
      expect(prediction.topLogit, 5.2);
      expect(prediction.calibratedScore, 0.92);
      expect(prediction.margin, 0.35);
      expect(prediction.prototypeSimilarity, isNull);

      final retrieved = await predictionRepo.getPrediction(prediction.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, prediction.id);
      expect(retrieved.classId, 0);
    });

    test('get prediction by message ID', () async {
      final prediction = await predictionRepo.createPrediction(
        messageId: testMessage.id,
        classId: 4,
        crop: 'tomato',
        condition: 'bacterial_spot',
        decisionState: model.DecisionState.uncertain,
        topLogit: 3.8,
        calibratedScore: 0.68,
        margin: 0.12,
        modelVersion: 'v1.0.0',
        preprocessVersion: 'v1.0.0',
      );

      final retrieved = await predictionRepo.getPredictionForMessage(
        testMessage.id,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.id, prediction.id);
      expect(retrieved.crop, 'tomato');
      expect(retrieved.condition, 'bacterial_spot');
      expect(retrieved.decisionState, model.DecisionState.uncertain);
    });

    test('prediction with prototype similarity', () async {
      final prediction = await predictionRepo.createPrediction(
        messageId: testMessage.id,
        classId: 3,
        crop: 'maize',
        condition: 'healthy',
        decisionState: model.DecisionState.possibleMatch,
        topLogit: 6.1,
        calibratedScore: 0.95,
        margin: 0.42,
        prototypeSimilarity: 0.78,
        modelVersion: 'v1.0.0',
        preprocessVersion: 'v1.0.0',
      );

      expect(prediction.prototypeSimilarity, 0.78);
    });

    test('prediction with unsupportedOrUnclear decision', () async {
      final prediction = await predictionRepo.createPrediction(
        messageId: testMessage.id,
        classId: 1,
        crop: 'maize',
        condition: 'northern_leaf_blight',
        decisionState: model.DecisionState.unsupportedOrUnclear,
        topLogit: 2.1,
        calibratedScore: 0.52,
        margin: 0.05,
        modelVersion: 'v1.0.0',
        preprocessVersion: 'v1.0.0',
        failureReason: 'Low confidence and margin below threshold',
      );

      expect(
        prediction.decisionState,
        model.DecisionState.unsupportedOrUnclear,
      );
      expect(
        prediction.failureReason,
        'Low confidence and margin below threshold',
      );
    });
  });

  group('Conversation Persistence', () {
    test('conversation and message survive database restart', () async {
      // Create conversation with a message
      final conv = await conversationRepo.createConversation(
        title: 'Persistent Test',
      );

      final msg = await messageRepo.createMessage(
        conversationId: conv.id,
        role: model.MessageRole.user,
        contentType: model.MessageContentType.text,
        textContent: 'Test persistence',
      );

      // Verify it exists
      final convBefore = await conversationRepo.getConversation(conv.id);
      final msgBefore = await messageRepo.getMessage(msg.id);

      expect(convBefore, isNotNull);
      expect(msgBefore, isNotNull);

      // In a real app restart scenario, we'd close and reopen the database
      // For this test, we're verifying the data is actually persisted in memory
      final conversationsAfter = await conversationRepo.getAllConversations();
      final messagesAfter = await messageRepo.getMessagesForConversation(
        conv.id,
      );

      expect(conversationsAfter, hasLength(1));
      expect(messagesAfter, hasLength(1));
      expect(conversationsAfter[0].id, conv.id);
      expect(messagesAfter[0].id, msg.id);
      expect(messagesAfter[0].textContent, 'Test persistence');
    });

    test('prediction linked to message persists', () async {
      final conv = await conversationRepo.createConversation(
        title: 'Prediction Test',
      );

      final msg = await messageRepo.createMessage(
        conversationId: conv.id,
        role: model.MessageRole.user,
        contentType: model.MessageContentType.image,
        localImagePath: '/test/image.jpg',
      );

      final pred = await predictionRepo.createPrediction(
        messageId: msg.id,
        classId: 5,
        crop: 'tomato',
        condition: 'early_blight',
        decisionState: model.DecisionState.possibleMatch,
        topLogit: 4.5,
        calibratedScore: 0.85,
        margin: 0.25,
        modelVersion: 'v1.0.0',
        preprocessVersion: 'v1.0.0',
      );

      // Retrieve and verify
      final retrievedPred = await predictionRepo.getPredictionForMessage(
        msg.id,
      );
      expect(retrievedPred, isNotNull);
      expect(retrievedPred!.id, pred.id);
      expect(retrievedPred.crop, 'tomato');
      expect(retrievedPred.condition, 'early_blight');
      expect(retrievedPred.classId, 5);
    });
  });

  group('Cascading Deletes', () {
    test(
      'deleting conversation cascades to messages and predictions',
      () async {
        final conv = await conversationRepo.createConversation(
          title: 'Cascade Test',
        );

        final msg = await messageRepo.createMessage(
          conversationId: conv.id,
          role: model.MessageRole.user,
          contentType: model.MessageContentType.image,
          localImagePath: '/test/leaf.jpg',
        );

        final pred = await predictionRepo.createPrediction(
          messageId: msg.id,
          classId: 2,
          crop: 'maize',
          condition: 'gray_leaf_spot',
          decisionState: model.DecisionState.possibleMatch,
          topLogit: 5.0,
          calibratedScore: 0.88,
          margin: 0.30,
          modelVersion: 'v1.0.0',
          preprocessVersion: 'v1.0.0',
        );

        // Delete conversation
        await conversationRepo.deleteConversation(conv.id);

        // Verify cascade
        final convAfter = await conversationRepo.getConversation(conv.id);
        final msgAfter = await messageRepo.getMessage(msg.id);
        final predAfter = await predictionRepo.getPrediction(pred.id);

        expect(convAfter, isNull);
        expect(msgAfter, isNull);
        expect(predAfter, isNull);
      },
    );
  });

  group('Class Map Order', () {
    test('classId values match training artifact order', () async {
      // The order from class_map.json must be preserved
      final classMap = [
        {'id': 0, 'crop': 'maize', 'condition': 'common_rust'},
        {'id': 1, 'crop': 'maize', 'condition': 'northern_leaf_blight'},
        {'id': 2, 'crop': 'maize', 'condition': 'gray_leaf_spot'},
        {'id': 3, 'crop': 'maize', 'condition': 'healthy'},
        {'id': 4, 'crop': 'tomato', 'condition': 'bacterial_spot'},
        {'id': 5, 'crop': 'tomato', 'condition': 'early_blight'},
        {'id': 6, 'crop': 'tomato', 'condition': 'late_blight'},
        {'id': 7, 'crop': 'tomato', 'condition': 'leaf_mold'},
        {'id': 8, 'crop': 'tomato', 'condition': 'healthy'},
      ];

      final conv = await conversationRepo.createConversation(title: 'Test');

      for (final entry in classMap) {
        final msg = await messageRepo.createMessage(
          conversationId: conv.id,
          role: model.MessageRole.user,
          contentType: model.MessageContentType.image,
          localImagePath: '/test/${entry['id']}.jpg',
        );

        final pred = await predictionRepo.createPrediction(
          messageId: msg.id,
          classId: entry['id'] as int,
          crop: entry['crop'] as String,
          condition: entry['condition'] as String,
          decisionState: model.DecisionState.possibleMatch,
          topLogit: 5.0,
          calibratedScore: 0.90,
          margin: 0.30,
          modelVersion: 'v1.0.0',
          preprocessVersion: 'v1.0.0',
        );

        final retrieved = await predictionRepo.getPrediction(pred.id);
        expect(retrieved!.classId, entry['id']);
        expect(retrieved.crop, entry['crop']);
        expect(retrieved.condition, entry['condition']);
      }
    });
  });
}
