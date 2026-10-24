import 'package:uuid/uuid.dart';
import '../models/conversation.dart' as model;
import '../models/message.dart' as model;
import 'database.dart';

/// Repository for conversation operations
class ConversationRepository {
  final AgriLensDatabase _db;
  final _uuid = const Uuid();

  ConversationRepository(this._db);

  /// Create a new conversation with optional initial message
  Future<model.Conversation> createConversation({
    String? title,
    model.MessageModel? initialMessage,
  }) async {
    final now = DateTime.now();
    final conversationId = _uuid.v4();

    final conversation = model.Conversation(
      id: conversationId,
      title: title ?? 'New Conversation',
      createdAt: now,
      updatedAt: now,
    );

    if (initialMessage != null) {
      final message = initialMessage.copyWith(conversationId: conversationId);
      await _db.createConversationWithMessage(
        conversation: _toDbConversation(conversation),
        message: _toDbMessage(message),
      );
    } else {
      await _db.createConversation(_toDbConversation(conversation));
    }

    return conversation;
  }

  /// Get a conversation by ID
  Future<model.Conversation?> getConversation(String id) async {
    final dbConv = await _db.getConversation(id);
    return dbConv != null ? _fromDbConversation(dbConv) : null;
  }

  /// Get all conversations, ordered by most recent first
  Future<List<model.Conversation>> getAllConversations() async {
    final dbConvs = await _db.getAllConversations();
    return dbConvs.map(_fromDbConversation).toList();
  }

  /// Update conversation title
  Future<void> updateConversationTitle(String id, String title) async {
    final conversation = await _db.getConversation(id);
    if (conversation != null) {
      await _db.updateConversation(
        conversation.copyWith(title: title, updatedAt: DateTime.now()),
      );
    }
  }

  /// Delete a conversation and clean up associated image files
  Future<void> deleteConversation(String id) async {
    await _db.deleteConversationWithCleanup(id);
  }

  /// Update conversation's updatedAt timestamp
  Future<void> touchConversation(String id) async {
    final conversation = await _db.getConversation(id);
    if (conversation != null) {
      await _db.updateConversation(
        conversation.copyWith(updatedAt: DateTime.now()),
      );
    }
  }

  // Conversion helpers
  Conversation _toDbConversation(model.Conversation conv) {
    return Conversation(
      id: conv.id,
      title: conv.title,
      createdAt: conv.createdAt,
      updatedAt: conv.updatedAt,
    );
  }

  model.Conversation _fromDbConversation(Conversation dbConv) {
    return model.Conversation(
      id: dbConv.id,
      title: dbConv.title,
      createdAt: dbConv.createdAt,
      updatedAt: dbConv.updatedAt,
    );
  }

  Message _toDbMessage(model.MessageModel msg) {
    return Message(
      id: msg.id,
      conversationId: msg.conversationId,
      role: msg.role.name,
      contentType: msg.contentType.name,
      textContent: msg.textContent,
      localImagePath: msg.localImagePath,
      lifecycle: msg.lifecycle.name,
      failureReason: msg.failureReason,
      createdAt: msg.createdAt,
      updatedAt: msg.updatedAt,
    );
  }
}
