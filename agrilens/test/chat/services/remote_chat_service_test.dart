import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:agrilens/app/chat/services/remote_chat_service.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConversationAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'conversation': {
        'id': 'conversation-1',
        'title': 'Test',
        'created_at': '2026-10-27T10:00:00Z',
        'updated_at': '2026-10-27T10:00:00Z',
      },
      'messages': [
        {
          'id': 'message-1',
          'role': 'user',
          'content_type': 'image',
          'lifecycle': 'complete',
          'created_at': '2026-10-27T10:00:00Z',
          'updated_at': '2026-10-27T10:00:00Z',
          'prediction': {
            'id': 'prediction-1',
            'message_id': 'message-1',
            'class_id': 33,
            'crop': 'tomato',
            'condition': 'thrips',
            'decision_state': 'possibleMatch',
            'top_logit': 4.2,
            'calibrated_score': 0.91,
            'margin': 0.42,
            'model_version': 'v2_34class_mobilenetv3',
            'preprocess_version': 'v1_224_imagenet',
            'created_at': '2026-10-27T10:00:00Z',
          },
        },
      ],
    }),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'server history accepts a condition outside the legacy local class map',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.org'))
        ..httpClientAdapter = _ConversationAdapter();
      final api = ApiClient(
        dio: dio,
        accessTokenProvider: () async => 'test-token',
      );
      final snapshot = await RemoteChatService(
        api,
      ).loadConversation('conversation-1');

      expect(snapshot.predictions['message-1']?.classId, 33);
      expect(snapshot.predictions['message-1']?.crop, 'tomato');
      expect(snapshot.predictions['message-1']?.condition, 'thrips');
    },
  );

  test(
    'answer metadata parses cited sources and verified product suggestions',
    () {
      final answer = AnswerMetadata.fromJson({
        'answer': 'Use the reviewed guidance below.',
        'sources': [
          {
            'id': 'source-1',
            'title': 'Tomato guidance',
            'organization': 'Extension service',
            'url': 'https://example.org/guidance',
          },
        ],
        'products': [
          {
            'id': 'product-1',
            'name': 'Verified product',
            'description': 'Evidence-backed use',
            'price': '4.20',
            'currency': 'USD',
            'evidence_source_url': 'https://example.org/evidence',
            'image_url': 'https://example.org/product.png',
          },
        ],
      });

      expect(answer.sources.single.title, 'Tomato guidance');
      expect(answer.sources.single.url, 'https://example.org/guidance');
      expect(answer.products.single.name, 'Verified product');
      expect(answer.products.single.price, '4.20');
      expect(
        answer.products.single.evidenceUrl,
        'https://example.org/evidence',
      );
    },
  );

  test('answer metadata tolerates missing optional collections', () {
    final answer = AnswerMetadata.fromJson({'answer': 'Try a clearer photo.'});
    expect(answer.sources, isEmpty);
    expect(answer.products, isEmpty);
  });

  test(
    'server marks persisted follow-up failures so the composer can clear',
    () {
      final request = RequestOptions(path: '/v1/answers');
      final error = ApiRequestException(
        'Gemini is unavailable',
        cause: DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 503,
            headers: Headers.fromMap({
              'x-agrilens-followup-saved': ['true'],
            }),
          ),
        ),
      );

      expect(error.followUpWasSaved, isTrue);
    },
  );
}
