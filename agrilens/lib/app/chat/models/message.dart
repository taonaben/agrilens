// Domain model for a message within a conversation.
// Stores role, content, optional image reference, and lifecycle state.

enum MessageRole { user, assistant, system }

enum MessageContentType { text, image }

enum MessageLifecycle { pending, complete, failed }

class Message {
  final String id;
  final String conversationId;
  final MessageRole role;
  final MessageContentType contentType;
  final String? textContent;
  final String? localImagePath;
  final MessageLifecycle lifecycle;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.contentType,
    this.textContent,
    this.localImagePath,
    required this.lifecycle,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  Message copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    MessageContentType? contentType,
    String? textContent,
    String? localImagePath,
    MessageLifecycle? lifecycle,
    String? failureReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      contentType: contentType ?? this.contentType,
      textContent: textContent ?? this.textContent,
      localImagePath: localImagePath ?? this.localImagePath,
      lifecycle: lifecycle ?? this.lifecycle,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
