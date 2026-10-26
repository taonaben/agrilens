// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  id: json['id'] as String?,
  sku: json['sku'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  price: (json['price'] as num?)?.toDouble(),
  currency: json['currency'] as String?,
  stockQuantity: (json['stock_quantity'] as num?)?.toInt(),
  crops: (json['crops'] as List<dynamic>?)?.map((e) => e as String).toList(),
  conditions:
      (json['conditions'] as List<dynamic>?)?.map((e) => e as String).toList(),
  active: json['active'] as bool?,
  imageUrl: json['image_url'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'id': instance.id,
  'sku': instance.sku,
  'name': instance.name,
  'description': instance.description,
  'price': instance.price,
  'currency': instance.currency,
  'stock_quantity': instance.stockQuantity,
  'crops': instance.crops,
  'conditions': instance.conditions,
  'active': instance.active,
  'image_url': instance.imageUrl,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};
