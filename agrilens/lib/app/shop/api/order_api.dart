import 'package:agrilens/shared/api/api_client.dart';

class OrderApi {
  OrderApi({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items,
    required String contactName,
    required String phone,
    required String deliveryAddress,
  }) {
    return _apiClient.postJson('/v1/orders', {
      'items': items,
      'contact_name': contactName,
      'phone': phone,
      'delivery_address': deliveryAddress,
    });
  }
}
