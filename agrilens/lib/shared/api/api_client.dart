// ignore_for_file: file_names

import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef ApiAccessTokenProvider = Future<String?> Function();
typedef ApiUnauthorizedHandler = Future<void> Function();

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _configuredBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _attachInterceptors(_dio);
  }

  void _attachInterceptors(Dio dio) {
    dio.interceptors.insert(
      0,
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            await _rateLimiter.waitForTurn(options.path);
            if (_requiresAuthorization(options)) {
              final accessToken = await _accessTokenProvider?.call();
              if (accessToken != null && accessToken.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $accessToken';
              } else {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error: const ApiRequestException(
                      'Sign in to use diagnosis and chat.',
                    ),
                  ),
                );
                return;
              }
            } else {
              options.headers.remove('Authorization');
            }
            handler.next(options);
          } catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              _requiresAuthorization(error.requestOptions)) {
            try {
              await _unauthorizedHandler?.call();
            } catch (_) {
              // Keep the original HTTP error while the app session is cleared.
            }
          }
          handler.next(error);
        },
      ),
    );

    // Do not log request or response bodies; auth requests contain passwords.
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
      ),
    );
  }

  static const Set<String> _publicEndpoints = {'/login', '/register'};
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient({
    ApiAccessTokenProvider? accessTokenProvider,
    ApiUnauthorizedHandler? unauthorizedHandler,
    String? baseUrl,
    Dio? dio,
  }) {
    if (accessTokenProvider != null) {
      _instance._accessTokenProvider = accessTokenProvider;
    }
    if (unauthorizedHandler != null) {
      _instance._unauthorizedHandler = unauthorizedHandler;
    }
    if (dio != null) {
      _instance._dio = dio;
      _instance._attachInterceptors(dio);
    }
    if (baseUrl != null) _instance._dio.options.baseUrl = baseUrl.trim();
    return _instance;
  }

  late Dio _dio;
  Dio get dio => _dio;

  ApiAccessTokenProvider? _accessTokenProvider;
  ApiUnauthorizedHandler? _unauthorizedHandler;
  final _ApiRateLimiter _rateLimiter = _ApiRateLimiter();

  bool get isConfigured => _dio.options.baseUrl.isNotEmpty;

  bool _requiresAuthorization(RequestOptions options) =>
      !_publicEndpoints.contains(_normalizedPath(options.path));

  static String _normalizedPath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return normalized.length > 1 && normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
    bool requiresAuth = true,
  }) async {
    if (requiresAuth) {
      try {
        if ((await _accessTokenProvider?.call())?.isNotEmpty != true) {
          throw const ApiRequestException('Sign in to use diagnosis and chat.');
        }
      } on ApiRequestException {
        rethrow;
      } catch (error) {
        throw ApiRequestException(
          'Could not read the saved sign-in session.',
          cause: error,
        );
      }
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        cancelToken: cancelToken,
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiRequestException(_messageFor(error), cause: error);
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      if ((await _accessTokenProvider?.call())?.isNotEmpty != true) {
        throw const ApiRequestException('Sign in to use local weather.');
      }
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      throw ApiRequestException(
        'Could not read the saved sign-in session.',
        cause: error,
      );
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiRequestException(_messageFor(error), cause: error);
    }
  }

  Future<Map<String, dynamic>> postImage(
    String path,
    String imagePath, {
    CancelToken? cancelToken,
  }) async {
    try {
      if ((await _accessTokenProvider?.call())?.isNotEmpty != true) {
        throw const ApiRequestException('Sign in to use diagnosis and chat.');
      }
    } on ApiRequestException {
      rethrow;
    } catch (error) {
      throw ApiRequestException(
        'Could not read the saved sign-in session.',
        cause: error,
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: FormData.fromMap({
          'image': await MultipartFile.fromFile(imagePath),
        }),
        cancelToken: cancelToken,
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiRequestException(_messageFor(error), cause: error);
    }
  }

  static String _messageFor(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List) {
        final validationErrors = <String>[];
        for (final issue in detail) {
          if (issue is! Map) continue;
          final location = issue['loc'];
          final message = issue['msg'];
          if (message is! String || message.isEmpty) continue;
          final field = location is Iterable ? location.skip(1).join('.') : '';
          validationErrors.add(field.isEmpty ? message : '$field: $message');
        }
        if (validationErrors.isNotEmpty) {
          return 'Please check: ${validationErrors.join('; ')}';
        }
      }
    }
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The server took too long to respond. Check your connection and retry.',
      DioExceptionType.connectionError =>
        'Could not reach the AgriLens server. Check your internet connection.',
      DioExceptionType.cancel => 'The request was cancelled.',
      _ => 'The server request failed. Please retry.',
    };
  }

  static String get _configuredBaseUrl {
    if (!dotenv.isInitialized) return '';
    return (dotenv.env['API_BASE_URL'] ?? '').trim();
  }
}

class ApiRequestException implements Exception {
  const ApiRequestException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class _ApiRateLimiter {
  _ApiRateLimiter({
    DateTime Function()? now,
    Future<void> Function(Duration delay)? delay,
  }) : _now = now ?? DateTime.now,
       _delay = delay ?? ((duration) => Future<void>.delayed(duration));

  static const _globalLimit = _RateLimit(
    maxRequests: 60,
    window: Duration(minutes: 1),
  );
  static const _defaultEndpointLimit = _RateLimit(
    maxRequests: 30,
    window: Duration(minutes: 1),
  );
  static const Map<String, _RateLimit> _endpointLimits = {
    '/users/otp/': _RateLimit(maxRequests: 3, window: Duration(minutes: 1)),
    '/users/register-login/': _RateLimit(
      maxRequests: 5,
      window: Duration(minutes: 1),
    ),
    '/users/refresh/': _RateLimit(
      maxRequests: 10,
      window: Duration(minutes: 1),
    ),
  };

  final DateTime Function() _now;
  final Future<void> Function(Duration delay) _delay;
  final Queue<DateTime> _globalRequests = Queue<DateTime>();
  final Map<String, Queue<DateTime>> _endpointRequests = {};

  Future<void> waitForTurn(String path) async {
    while (true) {
      final now = _now();
      final endpointLimit = _endpointLimits[path] ?? _defaultEndpointLimit;
      final endpointRequests = _endpointRequests.putIfAbsent(
        path,
        () => Queue<DateTime>(),
      );

      _prune(_globalRequests, now, _globalLimit.window);
      _prune(endpointRequests, now, endpointLimit.window);

      final globalDelay = _retryAfter(_globalRequests, now, _globalLimit);
      final endpointDelay = _retryAfter(endpointRequests, now, endpointLimit);
      final delay = globalDelay > endpointDelay ? globalDelay : endpointDelay;

      if (delay == Duration.zero) {
        _globalRequests.addLast(now);
        endpointRequests.addLast(now);
        return;
      }

      await _delay(delay);
    }
  }

  Duration _retryAfter(
    Queue<DateTime> requests,
    DateTime now,
    _RateLimit limit,
  ) {
    if (requests.length < limit.maxRequests) return Duration.zero;

    final retryAt = requests.first.add(limit.window);
    final delay = retryAt.difference(now);
    return delay.isNegative ? Duration.zero : delay;
  }

  void _prune(Queue<DateTime> requests, DateTime now, Duration window) {
    while (requests.isNotEmpty && now.difference(requests.first) >= window) {
      requests.removeFirst();
    }
  }
}

class _RateLimit {
  const _RateLimit({required this.maxRequests, required this.window});

  final int maxRequests;
  final Duration window;
}
