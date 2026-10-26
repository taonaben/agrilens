import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:solar_icons/solar_icons.dart';

import 'package:agrilens/app/shop/models/product_model.dart';
import 'package:agrilens/app/shop/state/cart_provider.dart';
import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/rendering.dart';

class ShopItemCard extends StatelessWidget {
  final Product product;
  const ShopItemCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showProductDetails(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _VisibleProductImage(imageUrl: product.imageUrl)),
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingXSmall),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name ?? "No Name",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(AppConstants.gapXSmall),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatPrice(product),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Consumer(
                        builder:
                            (context, ref, _) => IconButton(
                              tooltip: 'Add to cart',
                              icon: const Icon(SolarIconsOutline.addCircle),
                              onPressed:
                                  () => _addToCart(context, ref, product),
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
  }

  void _showProductDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: 0.88,
            child: _ProductDetailsSheet(product: product),
          ),
    );
  }
}

String _formatPrice(Product product) {
  final price = product.price?.toStringAsFixed(2) ?? '0.00';
  final currency = product.currency?.trim();
  return currency == null || currency.isEmpty ? '\$$price' : '$currency $price';
}

class _ProductDetailsSheet extends StatelessWidget {
  const _ProductDetailsSheet({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final crops = product.crops ?? const <String>[];
    final conditions = product.conditions ?? const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((product.imageUrl ?? '').trim().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: product.imageUrl!.trim(),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorWidget:
                      (context, url, error) => _detailImageFallback(context),
                  placeholder: (context, url) => _detailImageFallback(context),
                ),
              ),
            ),
            const Gap(20),
          ],
          Text(
            product.name?.trim().isNotEmpty == true
                ? product.name!.trim()
                : 'Product',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            softWrap: true,
          ),
          const Gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  _formatPrice(product),
                  style: textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _stockLabel(product.stockQuantity),
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if ((product.sku ?? '').trim().isNotEmpty) ...[
            const Gap(8),
            Text(
              'SKU ${product.sku!.trim()}',
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if ((product.description ?? '').trim().isNotEmpty) ...[
            const Gap(24),
            Text('About this product', style: textTheme.titleSmall),
            const Gap(8),
            Text(
              product.description!.trim(),
              style: textTheme.bodyMedium?.copyWith(height: 1.5),
              softWrap: true,
            ),
          ],
          if (crops.isNotEmpty) ...[
            const Gap(20),
            _ProductTagSection(title: 'Crops', values: crops),
          ],
          if (conditions.isNotEmpty) ...[
            const Gap(16),
            _ProductTagSection(title: 'Conditions', values: conditions),
          ],
          if (product.active != null) ...[
            const Gap(20),
            Text(
              product.active! ? 'Available' : 'Currently unavailable',
              style: textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const Gap(24),
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
    );
  }

  String _stockLabel(int? quantity) {
    if (quantity == null) return '';
    if (quantity <= 0) return 'Out of stock';
    return '$quantity in stock';
  }

  Widget _detailImageFallback(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(child: Icon(SolarIconsOutline.galleryMinimalistic)),
  );
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

class _ProductTagSection extends StatelessWidget {
  const _ProductTagSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const Gap(8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              Chip(
                label: Text(value, softWrap: true),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}

class _VisibleProductImage extends StatefulWidget {
  const _VisibleProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  State<_VisibleProductImage> createState() => _VisibleProductImageState();
}

class _VisibleProductImageState extends State<_VisibleProductImage> {
  ScrollPosition? _scrollPosition;
  bool _hasEnteredViewport = false;

  String? get _validImageUrl {
    final value = widget.imageUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (identical(nextPosition, _scrollPosition)) return;
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_scheduleVisibilityCheck);
    _scheduleVisibilityCheck();
  }

  @override
  void didUpdateWidget(covariant _VisibleProductImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasEnteredViewport = false;
      _scheduleVisibilityCheck();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    super.dispose();
  }

  void _scheduleVisibilityCheck() {
    if (_hasEnteredViewport || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasEnteredViewport || _validImageUrl == null) return;
      final item = context.findRenderObject();
      final viewport =
          context.findAncestorRenderObjectOfType<RenderAbstractViewport>();
      final viewportBox = viewport as RenderBox?;
      if (item is! RenderBox || viewportBox == null || !item.hasSize) return;

      final itemRect = item.localToGlobal(Offset.zero) & item.size;
      final viewportRect =
          viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
      if (itemRect.overlaps(viewportRect)) {
        setState(() => _hasEnteredViewport = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _validImageUrl;
    if (imageUrl == null) return _placeholder();
    if (!_hasEnteredViewport) return _placeholder();

    return ClipRect(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        imageBuilder:
            (context, imageProvider) => SizedBox.expand(
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
        errorWidget: (context, url, error) => _placeholder(),
        placeholder: (context, url) => _placeholder(loading: true),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) {
    if (loading) {
      return const Center(child: CustomProgressIndicator());
    }
    return const Center(child: Icon(SolarIconsOutline.galleryMinimalistic));
  }
}
