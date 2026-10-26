import 'package:agrilens/app/shop/components/shop_item_card.dart';
import 'package:agrilens/app/shop/state/cart_provider.dart';
import 'package:agrilens/app/shop/views/order_page.dart';
import 'package:agrilens/shared/components/custom_error_state.dart';
import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrilens/app/shop/state/shop_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopItemsAsyncValue = ref.watch(shopItemsProvider);

    return shopItemsAsyncValue.when(
      data: (shopItems) {
        final cart = ref.watch(cartProvider);
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingLarge,
                ),
                child: GridView.builder(
                  cacheExtent: 0,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3 / 4,
                    mainAxisSpacing: AppConstants.gapSmall,
                    crossAxisSpacing: AppConstants.gapSmall,
                  ),
                  itemCount: shopItems.length,
                  itemBuilder:
                      (context, index) =>
                          ShopItemCard(product: shopItems[index]),
                ),
              ),
            ),
            if (!cart.isEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingMedium),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const OrderPage(),
                            ),
                          ),
                      icon: const Icon(SolarIconsOutline.cartLargeMinimalistic),
                      label: Text(
                        'View cart (${cart.itemCount}) · ${_formatCartTotal(cart)}',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CustomProgressIndicator()),
      error:
          (error, stack) => Center(
            child: CustomErrorState(
              onRetry: () => ref.refresh(shopItemsProvider),
            ),
          ),
    );
    // return const Placeholder();
  }

  String _formatCartTotal(CartController cart) {
    final amount = cart.total.toStringAsFixed(2);
    final currency = cart.lines.first.product.currency?.trim();
    return currency == null || currency.isEmpty
        ? '\$$amount'
        : '$currency $amount';
  }
}
