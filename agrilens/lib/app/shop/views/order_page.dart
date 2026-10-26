import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agrilens/app/shop/state/cart_provider.dart';
import 'package:agrilens/app/shop/views/checkout_page.dart';
import 'package:agrilens/app/shop/models/product_model.dart';
import 'package:solar_icons/solar_icons.dart';

class OrderPage extends ConsumerWidget {
  const OrderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Your order'), centerTitle: true),
      body:
          cart.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final line = cart.lines[index];
                        final id = line.product.id!;
                        return Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child:
                                        line.product.imageUrl?.isNotEmpty ==
                                                true
                                            ? Image.network(
                                              line.product.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, _, _) =>
                                                      _imageFallback(context),
                                            )
                                            : _imageFallback(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.product.name ?? 'Product',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_price(line.product)),
                                      Row(
                                        children: [
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed:
                                                () => ref
                                                    .read(cartProvider)
                                                    .setQuantity(
                                                      id,
                                                      line.quantity - 1,
                                                    ),
                                            icon: const Icon(
                                              SolarIconsOutline.minusCircle,
                                            ),
                                          ),
                                          Text('${line.quantity}'),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed:
                                                () => ref
                                                    .read(cartProvider)
                                                    .addProduct(line.product),
                                            icon: const Icon(
                                              SolarIconsOutline.addCircle,
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            tooltip: 'Remove item',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed:
                                                () => ref
                                                    .read(cartProvider)
                                                    .remove(id),
                                            icon: const Icon(
                                              SolarIconsOutline
                                                  .trashBinMinimalistic, 
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _TotalRow(
                            total: cart.total,
                            currency: cart.lines.first.product.currency,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed:
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const CheckoutPage(),
                                    ),
                                  ),
                              child: const Text('Continue to delivery'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _imageFallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.image_outlined),
  );

  String _price(Product product) {
    final value = product.price?.toStringAsFixed(2) ?? '0.00';
    final currency = product.currency?.trim();
    return currency == null || currency.isEmpty
        ? '\$$value'
        : '$currency $value';
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total, required this.currency});

  final double total;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final amount = total.toStringAsFixed(2);
    final currencyCode = currency?.trim();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Order total'),
        Text(
          currencyCode == null || currencyCode.isEmpty
              ? '\$$amount'
              : '$currencyCode $amount',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
