import 'package:agrilens/shared/components/custom_error_state.dart';
import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrilens/app/shop/state/shop_provider.dart';

class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopItemsAsyncValue = ref.watch(shopItemsProvider);

    return shopItemsAsyncValue.when(
      data: (shopItems) {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3 / 4,
          ),
          itemCount: shopItems.length,
          itemBuilder: (context, index) {
            final product = shopItems[index];
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey[300],
                      child: Center(child: Text(product.name ?? "No Name")),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(product.description ?? "No Description"),
                  ),
                ],
              ),
            );
          },
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
}
