import 'package:uuid/uuid.dart';
import '../models/message.dart' as model;
import 'database.dart';

/// Repository for message operations
class MessageRepository {
  final AgriLensDatabase _db;
  final _uuid = const Uuid();

  MessageRepository(this._db);

  /// Create a new message in a conversation
  Future<model.Message> createMessage({
    required String conversationId,
    required model.MessageRole role,
    required model.MessageContentType contentType,
    String? textContent,
    String? localImagePath,
    model.MessageLifecycle lifecycle = model.MessageLifecycle.pending,
  }) async {
    final now = DateTime.now();
    final message = model.Message(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: role,
      contentType: contentType,
      textContent: textContent,
      localImagePath: localImagePath,
      lifecycle: lifecycle,
      createdAt: now,
      updatedAt: now,
    );

    await _db.createMessage(_toDbMessage(message));

    // Update conversation timestamp
    final conversation = await _db.getConversation(conversationId);
    if (conversation != null) {
      await _db.updateConversation(conversation.copyWith(updatedAt: now));
    }

    return message;
  }

  /// Get a message by ID
  Future<model.Message?> getMessage(String id) async {
    final dbMsg = await _db.getMessage(id);
    return dbMsg != null ? _fromDbMessage(dbMsg) : null;
  }

  /// Get all messages for a conversation, ordered by creation time
  Future<List<model.Message>> getMessagesForConversation(
    String conversationId,
  ) async {
    final dbMsgs = await _db.getMessagesForConversation(conversationId);
    return dbMsgs.map(_fromDbMessage).toList();
  }

  /// Update message lifecycle state
  Future<void> updateMessageLifecycle(
    String messageId,
    model.MessageLifecycle lifecycle, {
    String? failureReason,
  }) async {
    await _db.updateMessageLifecycle(
      messageId,
      lifecycle.name,
      failureReason: failureReason,
    );
  }

  /// Mark message as complete
  Future<void> markMessageComplete(String messageId) async {
    await updateMessageLifecycle(messageId, model.MessageLifecycle.complete);
  }

  /// Mark message as failed with reason
  Future<void> markMessageFailed(String messageId, String reason) async {
    await updateMessageLifecycle(
      messageId,
      model.MessageLifecycle.failed,
      failureReason: reason,
    );
  }

  // Conversion helpers
  Message _toDbMessage(model.Message msg) {
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

  model.Message _fromDbMessage(Message dbMsg) {
    return model.Message(
      id: dbMsg.id,
      conversationId: dbMsg.conversationId,
      role: _parseRole(dbMsg.role),
      contentType: _parseContentType(dbMsg.contentType),
      textContent: dbMsg.textContent,
      localImagePath: dbMsg.localImagePath,
      lifecycle: _parseLifecycle(dbMsg.lifecycle),
      failureReason: dbMsg.failureReason,
      createdAt: dbMsg.createdAt,
      updatedAt: dbMsg.updatedAt,
    );
  }

  model.MessageRole _parseRole(String role) {
    return model.MessageRole.values.firstWhere(
      (r) => r.name == role,
      orElse: () => model.MessageRole.user,
    );
  }

  model.MessageContentType _parseContentType(String type) {
    return model.MessageContentType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => model.MessageContentType.text,
    );
  }

  model.MessageLifecycle _parseLifecycle(String lifecycle) {
    return model.MessageLifecycle.values.firstWhere(
      (l) => l.name == lifecycle,
      orElse: () => model.MessageLifecycle.pending,
    );
  }
}
