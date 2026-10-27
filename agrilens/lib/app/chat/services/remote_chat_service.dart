import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:agrilens/app/shop/models/product_model.dart';

import '../../../shared/api/api_client.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/prediction.dart';

class AnswerSource {
  const AnswerSource({
    required this.title,
    required this.organization,
    required this.url,
  });
  final String title;
  final String organization;
  final String url;

  factory AnswerSource.fromJson(Map<String, dynamic> json) => AnswerSource(
    title: json['title'] as String? ?? 'Reviewed guidance',
    organization: json['organization'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );
}

class SuggestedProduct {
  const SuggestedProduct({
    this.id,
    this.sku,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.evidenceUrl,
    this.imageUrl,
    this.stockQuantity,
    this.crops = const [],
    this.conditions = const [],
  });
  final String name;
  final String? id;
  final String? sku;
  final String description;
  final String price;
  final String currency;
  final String evidenceUrl;
  final String? imageUrl;
  final int? stockQuantity;
  final List<String> crops;
  final List<String> conditions;

  factory SuggestedProduct.fromJson(Map<String, dynamic> json) =>
      SuggestedProduct(
        id: json['id'] as String?,
        sku: json['sku'] as String?,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: json['price']?.toString() ?? '',
        currency: json['currency'] as String? ?? '',
        evidenceUrl: json['evidence_source_url'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        stockQuantity: (json['stock_quantity'] as num?)?.toInt(),
        crops:
            (json['crops'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
        conditions:
            (json['conditions'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
      );

  Product toProduct() => Product(
    id: id,
    sku: sku,
    name: name,
    description: description,
    price: double.tryParse(price),
    currency: currency,
    stockQuantity: stockQuantity,
    crops: crops,
    conditions: conditions,
    active: true,
    imageUrl: imageUrl,
  );
}

class AnswerMetadata {
  const AnswerMetadata({this.sources = const [], this.products = const []});
  final List<AnswerSource> sources;
  final List<SuggestedProduct> products;

  factory AnswerMetadata.fromJson(Map<String, dynamic> json) => AnswerMetadata(
    sources:
        (json['sources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AnswerSource.fromJson)
            .toList(),
    products:
        (json['products'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SuggestedProduct.fromJson)
            .toList(),
  );
}

class RemoteConversationSnapshot {
  const RemoteConversationSnapshot({
    required this.conversation,
    required this.messages,
    required this.predictions,
    required this.answers,
  });
  final Conversation conversation;
  final List<MessageModel> messages;
  final Map<String, Prediction> predictions;
  final Map<String, AnswerMetadata> answers;
}

class RemoteChatService {
  RemoteChatService(this._api);
  final ApiClient _api;
  CancelToken? _activeRequest;

  CancelToken _newToken() => _activeRequest = CancelToken();
  void cancel() => _activeRequest?.cancel('Chat request cancelled by user.');

  Future<void> dispose() async {
    cancel();
    final directory = await getTemporaryDirectory();
    final imageDirectory = Directory(
      '${directory.path}/agrilens_remote_images',
    );
    if (await imageDirectory.exists()) {
      await imageDirectory.delete(recursive: true);
    }
  }

  Future<List<Conversation>> listConversations() async {
    final conversations = <Conversation>[];
    var offset = 0;
    while (true) {
      final body = await _api.getJson(
        '/v1/conversations',
        queryParameters: {'limit': 100, 'offset': offset},
      );
      final rows = body['conversations'];
      if (rows is! List) {
        throw const FormatException('Invalid conversation list.');
      }
      conversations.addAll(
        rows.whereType<Map<String, dynamic>>().map(_conversation),
      );
      if (rows.length < 100) break;
      offset += 100;
    }
    return conversations;
  }

  Future<Conversation> createConversation(String title) async {
    final row = await _api.postJson('/v1/conversations', {'title': title});
    return _conversation(row);
  }

  Future<void> deleteConversation(String id) => _deleteConversationAndCache(id);

  Future<void> _deleteConversationAndCache(String id) async {
    final body = await _api.getJson('/v1/conversations/$id');
    final rows = body['messages'] as List<dynamic>? ?? const [];
    await _api.delete('/v1/conversations/$id');
    final directory = await getTemporaryDirectory();
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final file = File(
        '${directory.path}/agrilens_remote_images/${row['id']}.jpg',
      );
      if (await file.exists()) await file.delete();
    }
  }

  Future<RemoteConversationSnapshot> loadConversation(String id) async {
    final body = await _api.getJson('/v1/conversations/$id');
    final conversation = _conversation(
      body['conversation'] as Map<String, dynamic>,
    );
    final rows = body['messages'] as List<dynamic>? ?? const [];
    final messages = <MessageModel>[];
    final predictions = <String, Prediction>{};
    final answers = <String, AnswerMetadata>{};
    for (final raw in rows.whereType<Map<String, dynamic>>()) {
      final messageId = raw['id'] as String;
      String? imagePath;
      final imageUrl = raw['image_url'];
      if (imageUrl is String && imageUrl.isNotEmpty) {
        final bytes = await _api.getBytes(imageUrl);
        final directory = await getTemporaryDirectory();
        final imageDirectory = Directory(
          '${directory.path}/agrilens_remote_images',
        );
        await imageDirectory.create(recursive: true);
        imagePath = '${imageDirectory.path}/$messageId.jpg';
        await File(imagePath).writeAsBytes(bytes, flush: true);
      }
      final message = MessageModel(
        id: messageId,
        conversationId: id,
        role: _enumValue(MessageRole.values, raw['role'], MessageRole.user),
        contentType: _enumValue(
          MessageContentType.values,
          raw['content_type'],
          MessageContentType.text,
        ),
        textContent: raw['text_content'] as String?,
        localImagePath: imagePath,
        lifecycle: _enumValue(
          MessageLifecycle.values,
          raw['lifecycle'],
          MessageLifecycle.complete,
        ),
        failureReason: raw['failure_reason'] as String?,
        createdAt:
            DateTime.tryParse(raw['created_at'] as String? ?? '') ??
            DateTime.now(),
        updatedAt:
            DateTime.tryParse(raw['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );
      messages.add(message);
      final predictionJson = raw['prediction'];
      if (predictionJson is Map<String, dynamic>) {
        final prediction = _prediction(predictionJson, messageId);
        predictions[messageId] = prediction;
      }
      final metadata = raw['response_metadata'];
      if (metadata is Map<String, dynamic> && metadata.isNotEmpty) {
        answers[messageId] = AnswerMetadata.fromJson(metadata);
      }
    }
    return RemoteConversationSnapshot(
      conversation: conversation,
      messages: messages,
      predictions: predictions,
      answers: answers,
    );
  }

  Future<AnswerMetadata> diagnose(
    String conversationId,
    String imagePath, {
    void Function()? onDiagnosisSaved,
  }) async {
    final token = _newToken();
    final raw = await _api.postImage(
      '/v1/diagnoses',
      imagePath,
      fields: {'conversation_id': conversationId},
      cancelToken: token,
    );
    _prediction(raw, '');
    onDiagnosisSaved?.call();
    final answer = await _api.postJson('/v1/answers', {
      'conversation_id': conversationId,
    }, cancelToken: token);
    return AnswerMetadata.fromJson(answer);
  }

  Future<AnswerMetadata> ask(String conversationId, String text) async {
    final token = _newToken();
    final answer = await _api.postJson('/v1/answers', {
      'conversation_id': conversationId,
      'user_follow_up': text,
    }, cancelToken: token);
    return AnswerMetadata.fromJson(answer);
  }

  Future<AnswerMetadata> retry(String conversationId) async {
    final token = _newToken();
    final answer = await _api.postJson('/v1/answers', {
      'conversation_id': conversationId,
    }, cancelToken: token);
    return AnswerMetadata.fromJson(answer);
  }

  static Conversation _conversation(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    title: json['title'] as String? ?? 'Conversation',
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updated_at'] as String? ?? '') ??
        DateTime.now(),
  );

  static Prediction _prediction(Map<String, dynamic> json, String messageId) {
    final classId = json['class_id'] as int;
    final crop = json['crop'] as String?;
    final condition = json['condition'] as String?;
    if (classId < 0 ||
        (crop != 'maize' && crop != 'tomato') ||
        condition == null ||
        condition.trim().isEmpty) {
      throw const FormatException(
        'The saved prediction has invalid crop-condition metadata.',
      );
    }
    final state = switch (json['decision_state']) {
      'possible_match' || 'possibleMatch' => DecisionState.possibleMatch,
      'unsupported_or_unclear' ||
      'unsupportedOrUnclear' => DecisionState.unsupportedOrUnclear,
      _ => DecisionState.uncertain,
    };
    return Prediction(
      id: json['id'] as String? ?? 'prediction-$messageId',
      messageId: (json['message_id'] as String?) ?? messageId,
      classId: classId,
      crop: crop!,
      condition: condition,
      decisionState: state,
      topLogit: (json['top_logit'] as num?)?.toDouble() ?? 0,
      calibratedScore: (json['calibrated_score'] as num).toDouble(),
      margin: (json['margin'] as num).toDouble(),
      prototypeSimilarity: (json['prototype_similarity'] as num?)?.toDouble(),
      modelVersion: json['model_version'] as String? ?? 'unknown',
      preprocessVersion: json['preprocess_version'] as String? ?? 'unknown',
      failureReason: json['failure_reason'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static T _enumValue<T extends Enum>(List<T> values, dynamic raw, T fallback) {
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }
}
