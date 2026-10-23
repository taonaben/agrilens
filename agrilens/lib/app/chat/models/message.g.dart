// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: json['id'] as String?,
  conversationId: json['conversationId'] as String?,
  role: $enumDecodeNullable(_$RoleEnumMap, json['role']),
  type: $enumDecodeNullable(_$MessageTypeEnumMap, json['type']),
  content: json['content'] as String?,
  imagePath: json['imagePath'] as String?,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
  'id': instance.id,
  'conversationId': instance.conversationId,
  'role': _$RoleEnumMap[instance.role],
  'type': _$MessageTypeEnumMap[instance.type],
  'content': instance.content,
  'imagePath': instance.imagePath,
  'createdAt': instance.createdAt?.toIso8601String(),
};

const _$RoleEnumMap = {
  Role.user: 'user',
  Role.assistant: 'assistant',
  Role.system: 'system',
};

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.prediction: 'prediction',
};
