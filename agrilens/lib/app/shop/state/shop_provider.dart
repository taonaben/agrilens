import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrilens/app/shop/services/shop_services.dart';
import 'package:agrilens/app/shop/models/product_model.dart';

final packageServiceProvider = Provider<ShopServices>((ref) {
  return ShopServices();
});

final shopItemsProvider = FutureProvider<List<Product>>((ref) async {
  final shopServices = ref.read(packageServiceProvider);
  return shopServices.getShopItems();
});
