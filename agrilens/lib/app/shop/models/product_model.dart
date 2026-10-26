import 'package:json_annotation/json_annotation.dart';
part 'product_model.g.dart';

@JsonSerializable()
class Product {
  final String? id;
  final String? sku;
  final String? name;
  final String? description;
  final double? price;
  final String? currency;
  @JsonKey(name: 'stock_quantity')
  final int? stockQuantity;
  final List<String>? crops;
  final List<String>? conditions;
  final bool? active;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  Product({
    this.id,
    this.sku,
    this.name,
    this.description,
    this.price,
    this.currency,
    this.stockQuantity,
    this.crops,
    this.conditions,
    this.active,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
