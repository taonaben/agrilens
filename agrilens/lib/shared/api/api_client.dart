import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

typedef AccessTokenProvider = Future<String?> Function();

class BackendApiClient {
  final Dio _dio;
  final AccessTokenProvider _accessTokenProvider;

  BackendApiClient.ApiClient({
    required AccessTokenProvider accessTokenProvider,
    String? baseUrl,
  }) : _accessTokenProvider = accessTokenProvider,
       _dio = Dio(
         BaseOptions(
           baseUrl: (baseUrl ?? _configuredBaseUrl).trim(),
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 90),
           sendTimeout: const Duration(seconds: 45),
           headers: const {'Accept': 'application/json'},
         ),
       );

  static String get _configuredBaseUrl {
    if (!dotenv.isInitialized) return '';
    return dotenv.env['API_BASE_URL'] ?? '';
  }

  bool get isConfigured {
    final url = _dio.options.baseUrl;
    return url.startsWith('https://') ||
        url.startsWith('http://10.0.2.2') ||
        url.startsWith('http://localhost') ||
        url.startsWith('http://127.0.0.1');
  }

  Future<Options> _authenticatedOptions() async {
    if (!isConfigured) {
      throw const BackendRequestException(
        'The AgriLens server URL is not configured.',
      );
    }
    final token = await _accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const BackendRequestException('Sign in to use diagnosis and chat.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async {
    try {
      final options = await _authenticatedOptions();
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw BackendRequestException(_messageFor(error), cause: error);
    }
  }

  Future<Map<String, dynamic>> postImage(
    String path,
    String imagePath, {
    CancelToken? cancelToken,
  }) async {
    try {
      final options = await _authenticatedOptions();
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: FormData.fromMap({
          'image': await MultipartFile.fromFile(imagePath),
        }),
        options: options,
        cancelToken: cancelToken,
      );
      return response.data ?? const {};
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw BackendRequestException(_messageFor(error), cause: error);
    }
  }

  static String _messageFor(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
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
}

class BackendRequestException implements Exception {
  final String message;
  final Object? cause;

  const BackendRequestException(this.message, {this.cause});

  @override
  String toString() => message;
}
