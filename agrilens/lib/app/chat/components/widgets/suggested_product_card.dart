import 'package:agrilens/app/chat/services/remote_chat_service.dart';
import 'package:agrilens/app/shop/models/product_model.dart';
import 'package:agrilens/app/shop/state/cart_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';

/// A compact product link shown beneath an assistant answer.
class SuggestedProductCard extends StatelessWidget {
  const SuggestedProductCard({super.key, required this.suggestion});

  final SuggestedProduct suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = _formatPrice(suggestion);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width < 600 ? 320 : 460,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showDetails(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.shop,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const Gap(9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            suggestion.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            price,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(6),
                    Text(
                      'Details',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(3),
                    Icon(
                      SolarIconsOutline.altArrowRight,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => _SuggestedProductDetails(
            suggestion: suggestion,
            product: suggestion.toProduct(),
          ),
    );
  }
}

class _SuggestedProductDetails extends StatelessWidget {
  const _SuggestedProductDetails({
    required this.suggestion,
    required this.product,
  });

  final SuggestedProduct suggestion;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = _formatPrice(suggestion);
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((suggestion.imageUrl ?? '').trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: suggestion.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _imageFallback(context),
                    placeholder: (_, _) => _imageFallback(context),
                  ),
                ),
              ),
              const Gap(18),
            ],
            Text(
              suggestion.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(6),
            Text(
              price,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (suggestion.stockQuantity != null) ...[
              const Gap(6),
              Text(
                suggestion.stockQuantity! > 0
                    ? '${suggestion.stockQuantity} in stock'
                    : 'Out of stock',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (suggestion.description.trim().isNotEmpty) ...[
              const Gap(20),
              Text('About this product', style: theme.textTheme.titleSmall),
              const Gap(6),
              Text(suggestion.description),
            ],
            if (suggestion.crops.isNotEmpty ||
                suggestion.conditions.isNotEmpty) ...[
              const Gap(18),
              Text('Recommended for', style: theme.textTheme.titleSmall),
              const Gap(6),
              Text([...suggestion.crops, ...suggestion.conditions].join(' · ')),
            ],
            const Gap(20),
            TextButton.icon(
              onPressed: () => _openEvidence(suggestion.evidenceUrl),
              icon: const Icon(SolarIconsOutline.link),
              label: const Text('View product information source'),
            ),
            const Gap(12),
            Consumer(
              builder:
                  (context, ref, _) => SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _addToCart(context, ref, product),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add to cart'),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(SolarIconsOutline.galleryMinimalistic)),
  );
}

String _formatPrice(SuggestedProduct product) {
  final amount = double.tryParse(product.price);
  final price = amount == null ? product.price : amount.toStringAsFixed(2);
  return product.currency.trim().isEmpty ? price : '${product.currency} $price';
}

void _addToCart(BuildContext context, WidgetRef ref, Product product) {
  final added = ref.read(cartProvider).addProduct(product);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          added ? 'Added to cart' : 'This item is unavailable or out of stock',
        ),
      ),
    );
}

Future<void> _openEvidence(String value) async {
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
