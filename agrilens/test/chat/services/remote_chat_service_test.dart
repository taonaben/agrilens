import 'package:dio/dio.dart';
import 'package:agrilens/app/chat/services/remote_chat_service.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
