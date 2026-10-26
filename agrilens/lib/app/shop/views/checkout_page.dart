import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:agrilens/shared/components/custom_textfield.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agrilens/app/shop/api/order_api.dart';
import 'package:agrilens/app/shop/state/cart_provider.dart';
import 'package:gap/gap.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _orderApi = OrderApi();
  bool _submitting = false;

  @override
  void dispose() {
    _contactNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery details')),
      body:
          cart.isEmpty
              ? const Center(child: Text('Your cart is empty'))
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Where should we deliver?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add your contact details to place the order.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    CustomTextfield(
                      controller: _contactNameController,
                      textCapitalization: TextCapitalization.words,
                      labelText: 'Contact name',
                      validator:
                          (value) => _validateLength(
                            value,
                            label: 'Contact name',
                            minimum: 1,
                            maximum: 160,
                          ),
                    ),
                    const Gap(AppConstants.gapMedium),

                    CustomTextfield(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      labelText: 'Phone number',
                      validator: (value) {
                        return _validateLength(
                          value,
                          label: 'Phone number',
                          minimum: 5,
                          maximum: 40,
                        );
                      },
                    ),
                    const Gap(AppConstants.gapMedium),
                    CustomTextfield(
                      controller: _addressController,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      labelText: 'Delivery address',
                      validator:
                          (value) => _validateLength(
                            value,
                            label: 'Delivery address',
                            minimum: 5,
                            maximum: 1000,
                          ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submitOrder,
                        child:
                            _submitting
                                ? const SizedBox.square(
                                  dimension: 20,
                                  child: CustomProgressIndicator(),
                                )
                                : const Text('Place order'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  String? _validateLength(
    String? value, {
    required String label,
    required int minimum,
    required int maximum,
  }) {
    final length = value?.trim().length ?? 0;
    if (length < minimum) return '$label must be at least $minimum characters';
    if (length > maximum) return '$label must be $maximum characters or less';
    return null;
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final lines = ref.read(cartProvider).lines;
    if (lines.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await _orderApi.createOrder(
        items: [
          for (final line in lines)
            {'product_id': line.product.id, 'quantity': line.quantity},
        ],
        contactName: _contactNameController.text.trim(),
        phone: _phoneController.text.trim(),
        deliveryAddress: _addressController.text.trim(),
      );

      if (!mounted) return;
      ref.read(cartProvider).clear();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Order placed')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not place order: $error')),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
