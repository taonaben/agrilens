// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prediction.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Prediction _$PredictionFromJson(Map<String, dynamic> json) => Prediction(
  id: json['id'] as String?,
  messageId: json['messageId'] as String?,
  crop: $enumDecodeNullable(_$CropEnumMap, json['crop']),
  result: json['result'] as String?,
  confidence: json['confidence'] as bool?,
  modelVersion: json['modelVersion'] as String?,
  createdAt:
      json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$PredictionToJson(Prediction instance) =>
    <String, dynamic>{
      'id': instance.id,
      'messageId': instance.messageId,
      'crop': _$CropEnumMap[instance.crop],
      'result': instance.result,
      'confidence': instance.confidence,
      'modelVersion': instance.modelVersion,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$CropEnumMap = {Crop.maize: 'maize', Crop.tomato: 'tomato'};
