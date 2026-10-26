import 'package:agrilens/app/shop/models/product_model.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/shared/utils/api_response.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:agrilens/shared/utils/logs.dart';
import 'package:dio/dio.dart';

class ShopApi {
  ShopApi({Dio? dio}) : _dio = dio ?? ApiClient().dio;

  final Dio _dio;

  final String productEndpoint = '/v1/products';

  Future<ApiResponse> getShopItems() async {
    try {
      final response = await _dio.get(productEndpoint);
      
      if(AppConstants.successStatusCodes.contains(response.statusCode)) {
        
        final payload = response.data;
        final rawItems =
            payload is List
                ? payload
                : payload is Map<String, dynamic>
                ? payload['results']
                : null;

        if (rawItems is! List) {
          return ApiResponse(
            message: 'Unexpected package list response format',
            success: false,
            data: const <Product>[],
          );
        }

        final products =
            rawItems
                .map(
                  (item) => Product.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
        
        return ApiResponse(
          success: true,
          message: 'Success',
          data: products,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Failed with status code: ${response.statusCode}',
          data: response.data,
        );
      }

    } on DioException catch (e) {
      if (e.response != null) {
        final responseData = e.response?.data;
        final message =
            responseData is Map
                ? (responseData['message'] ??
                        responseData['detail'] ??
                        responseData['error'])
                    ?.toString()
                : null;
        DevLogs.logError(
          'Failed to fetch packages (${e.response?.statusCode}): '
          '${message ?? e.message}',
        );
        return ApiResponse(
          success: false,
          message: message ?? 'An error occurred',
          data: {},
        );
      } else {
        DevLogs.logError("Network error: ${e.message}");
        return ApiResponse(
          success: false,
          message: 'Network error: ${e.message}',
          data: {},
        );
      }
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
