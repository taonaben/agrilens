import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Conversations table - stores conversation threads
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Messages table - stores user and assistant messages
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // user, assistant, system
  TextColumn get contentType => text()(); // text, image
  TextColumn get textContent => text().nullable()();
  TextColumn get localImagePath => text().nullable()();
  TextColumn get lifecycle => text()(); // pending, complete, failed
  TextColumn get failureReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Predictions table - stores classifier results
class Predictions extends Table {
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().references(Messages, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId => integer()();
  TextColumn get crop => text()();
  TextColumn get condition => text()();
  TextColumn get decisionState =>
      text()(); // possibleMatch, uncertain, unsupportedOrUnclear
  RealColumn get topLogit => real()();
  RealColumn get calibratedScore => real()();
  RealColumn get margin => real()();
  RealColumn get prototypeSimilarity => real().nullable()();
  TextColumn get modelVersion => text()();
  TextColumn get preprocessVersion => text()();
  TextColumn get failureReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Conversations, Messages, Predictions])
class AgriLensDatabase extends _$AgriLensDatabase {
  AgriLensDatabase() : super(_openConnection());

  // Constructor for testing with custom executor
  AgriLensDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will be handled here
      },
    );
  }

  // Conversations queries
  Future<List<Conversation>> getAllConversations() {
    return (select(conversations)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  Future<Conversation?> getConversation(String id) {
    return (select(conversations)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> createConversation(Conversation conversation) {
    return into(conversations).insert(conversation);
  }

  Future<bool> updateConversation(Conversation conversation) {
    return update(conversations).replace(conversation);
  }

  Future<int> deleteConversation(String id) {
    return (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  // Messages queries
  Future<List<Message>> getMessagesForConversation(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<Message?> getMessage(String id) {
    return (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> createMessage(Message message) {
    return into(messages).insert(message);
  }

  Future<bool> updateMessage(Message message) {
    return update(messages).replace(message);
  }

  Future<int> updateMessageLifecycle(
    String messageId,
    String lifecycle, {
    String? failureReason,
  }) {
    return (update(messages)..where((t) => t.id.equals(messageId))).write(
      MessagesCompanion(
        lifecycle: Value(lifecycle),
        failureReason: Value(failureReason),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> updateMessageTextAndLifecycle(
    String messageId,
    String textContent,
    String lifecycle,
  ) {
    return (update(messages)..where((t) => t.id.equals(messageId))).write(
      MessagesCompanion(
        textContent: Value(textContent),
        lifecycle: Value(lifecycle),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Predictions queries
  Future<Prediction?> getPredictionForMessage(String messageId) {
    return (select(predictions)
      ..where((t) => t.messageId.equals(messageId))).getSingleOrNull();
  }

  Future<Prediction?> getPrediction(String id) {
    return (select(predictions)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> createPrediction(Prediction prediction) {
    return into(predictions).insert(prediction);
  }

  Future<bool> updatePrediction(Prediction prediction) {
    return update(predictions).replace(prediction);
  }

  // Transaction: create conversation with initial message
  Future<void> createConversationWithMessage({
    required Conversation conversation,
    required Message message,
  }) async {
    await transaction(() async {
      await into(conversations).insert(conversation);
      await into(messages).insert(message);
    });
  }

  // Transaction: create message with prediction
  Future<void> createMessageWithPrediction({
    required String conversationId,
    required Message message,
    required Prediction prediction,
  }) async {
    await transaction(() async {
      final updatedRows =
          await (update(messages)..where((t) => t.id.equals(message.id))).write(
        MessagesCompanion(
          lifecycle: Value(message.lifecycle),
          failureReason: Value(message.failureReason),
          updatedAt: Value(message.updatedAt),
        ),
      );
      if (updatedRows == 0) {
        throw StateError(
          'Cannot attach prediction: message ${message.id} was not found.',
        );
      }
      await into(predictions).insert(prediction);
      // Update conversation updatedAt timestamp
      await (update(conversations)..where(
        (t) => t.id.equals(conversationId),
      )).write(ConversationsCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  // Clean up image file when conversation is deleted
  Future<void> deleteConversationWithCleanup(String conversationId) async {
    // Get all messages with images
    final messagesWithImages =
        await (select(messages)
              ..where((t) => t.conversationId.equals(conversationId))
              ..where((t) => t.localImagePath.isNotNull()))
            .get();

    await transaction(() async {
      // Delete from database (cascades to messages and predictions)
      await (delete(conversations)
        ..where((t) => t.id.equals(conversationId))).go();
    });

    // Clean up image files after successful database deletion
    for (final message in messagesWithImages) {
      if (message.localImagePath != null) {
        try {
          final file = File(message.localImagePath!);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Log but don't fail the operation (use logger in production)
          // ignore: avoid_print
          print(
            'Warning: Could not delete image file: ${message.localImagePath}',
          );
        }
      }
    }
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'agrilens_db',
    native: DriftNativeOptions(
      // Enable foreign keys for cascade deletes
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}
