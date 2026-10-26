import 'package:agrilens/app/shop/api/shop_api.dart';
import 'package:agrilens/app/shop/models/product_model.dart';

class ShopServices {
  final ShopApi _shopApi = ShopApi();

  Future<List<Product>> getShopItems() async {
    final response = await _shopApi.getShopItems();
    if (response.success) {
      return response.data as List<Product>;
    } else {
      throw Exception(response.message);
    }
  }
}