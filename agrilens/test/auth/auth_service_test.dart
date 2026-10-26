import 'dart:convert';
import 'dart:typed_data';

import 'package:agrilens/app/auth/services/auth_service.dart';
import 'package:agrilens/app/auth/services/auth_session.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/shared/routes/routes.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryTokenStorage implements AuthTokenStorage {
  String? token;

  @override
  Future<String?> read(String key) async => token;

  @override
  Future<void> write(String key, String value) async {
    token = value;
  }

  @override
  Future<void> delete(String key) async {
    token = null;
  }
}

class _CapturedRequest {
  const _CapturedRequest(this.options, this.body);

  final RequestOptions options;
  final String body;
}

class _TestHttpAdapter implements HttpClientAdapter {
  _TestHttpAdapter(this.requests);

  final List<_CapturedRequest> requests;
  bool malformedLoginResponse = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bodyBytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bodyBytes.addAll(chunk);
      }
    }
    requests.add(_CapturedRequest(options, utf8.decode(bodyBytes)));

    if (options.path == '/unauthorized') {
      return ResponseBody.fromString(
        jsonEncode({'detail': 'Invalid token'}),
        401,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path == '/login') {
      return ResponseBody.fromString(
        jsonEncode(
          malformedLoginResponse
              ? {'token': 'wrong-field'}
              : {'access_token': 'test-token'},
        ),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(options.path == '/protected' ? {'ok': true} : {}),
      options.path == '/register' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MemoryTokenStorage storage;
  late AuthSession session;
  late List<_CapturedRequest> requests;
  late _TestHttpAdapter adapter;
  late ApiClient api;

  setUp(() {
    storage = _MemoryTokenStorage();
    session = AuthSession(storage: storage);
    requests = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
    adapter = _TestHttpAdapter(requests);
    dio.httpClientAdapter = adapter;
    api = ApiClient(
      accessTokenProvider: session.readAccessToken,
      unauthorizedHandler: session.signOut,
      dio: dio,
    );
  });

  tearDown(() => session.dispose());

  test('login saves access token and sends no authorization header', () async {
    storage.token = 'stale-token';
    final auth = AuthService(api: api, session: session);
    await auth.signIn(email: 'farmer@example.com', password: 'password123');

    expect(storage.token, 'test-token');
    expect(requests.single.options.path, '/login');
    expect(jsonDecode(requests.single.body), {
      'email': 'farmer@example.com',
      'password': 'password123',
    });
    expect(
      requests.single.options.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('login reports a malformed token response without saving it', () async {
    adapter.malformedLoginResponse = true;
    final auth = AuthService(api: api, session: session);

    await expectLater(
      auth.signIn(email: 'farmer@example.com', password: 'password123'),
      throwsA(isA<ApiRequestException>()),
    );

    expect(storage.token, isNull);
  });

  test('registration signs in with the same credentials', () async {
    final auth = AuthService(api: api, session: session);
    await auth.register(email: 'farmer@example.com', password: 'password123');

    expect(storage.token, 'test-token');
    expect(requests.map((request) => request.options.path), [
      '/register',
      '/login',
    ]);
    for (final request in requests) {
      expect(jsonDecode(request.body), {
        'email': 'farmer@example.com',
        'password': 'password123',
      });
      expect(request.options.headers.containsKey('Authorization'), isFalse);
    }
  });

  test('authenticated calls send the saved bearer token', () async {
    storage.token = 'persisted-token';
    await api.postJson('/protected', const {});

    expect(
      requests.single.options.headers['Authorization'],
      'Bearer persisted-token',
    );
  });

  test('a protected 401 clears the saved session', () async {
    storage.token = 'expired-token';

    await expectLater(
      api.postJson('/unauthorized', const {}),
      throwsA(isA<ApiRequestException>()),
    );

    expect(storage.token, isNull);
    expect(session.isAuthenticated, isFalse);
  });

  test('restores a saved session and clears it on sign out', () async {
    storage.token = 'saved-token';

    await session.restore();
    expect(session.isReady, isTrue);
    expect(session.isAuthenticated, isTrue);

    await session.signOut();
    expect(storage.token, isNull);
    expect(session.isAuthenticated, isFalse);
  });

  testWidgets('auth gate redirects unauthenticated users to login', (
    tester,
  ) async {
    await session.restore();
    final router = createRouter(
      initialRoute: '/',
      authSession: session,
      apiClient: api,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to AgriLens'), findsOneWidget);
    router.dispose();
  });
}
