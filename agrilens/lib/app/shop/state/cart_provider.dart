import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agrilens/app/shop/models/product_model.dart';

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => (product.price ?? 0) * quantity;
}

class CartController extends ChangeNotifier {
  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => List.unmodifiable(_lines.values);
  int get itemCount =>
      _lines.values.fold(0, (sum, line) => sum + line.quantity);
  double get total => _lines.values.fold(0, (sum, line) => sum + line.subtotal);
  bool get isEmpty => _lines.isEmpty;

  bool addProduct(Product product) {
    final id = product.id;
    if (id == null || id.isEmpty || product.active == false) return false;
    final current = _lines[id]?.quantity ?? 0;
    final stock = product.stockQuantity;
    if ((stock != null && current >= stock) || current >= 1000) return false;
    if (current == 0 && _lines.length >= 50) return false;
    _lines[id] = CartLine(product: product, quantity: current + 1);
    notifyListeners();
    return true;
  }

  void setQuantity(String productId, int quantity) {
    final line = _lines[productId];
    if (line == null) return;
    if (quantity <= 0) {
      _lines.remove(productId);
    } else {
      final stock = line.product.stockQuantity;
      _lines[productId] = CartLine(
        product: line.product,
        quantity: stock == null ? quantity : quantity.clamp(1, stock).toInt(),
      );
    }
    notifyListeners();
  }

  void remove(String productId) {
    if (_lines.remove(productId) != null) notifyListeners();
  }

  void clear() {
    if (_lines.isEmpty) return;
    _lines.clear();
    notifyListeners();
  }
}

final cartProvider = ChangeNotifierProvider<CartController>(
  (ref) => CartController(),
);
