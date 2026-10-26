// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'single_forecast.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SingleForecast _$SingleForecastFromJson(Map<String, dynamic> json) =>
    SingleForecast(
      forecastAt: DateTime.parse(json['forecastAt'] as String),
      temperatureC: (json['temperatureC'] as num).toDouble(),
      feelsLikeC: (json['feelsLikeC'] as num).toDouble(),
      humidityPercent: (json['humidityPercent'] as num).toInt(),
      windSpeedMS: (json['windSpeedMS'] as num).toDouble(),
      precipitationProbability:
          (json['precipitationProbability'] as num).toDouble(),
      rain3hMm: (json['rain3hMm'] as num).toDouble(),
      snow3hMm: (json['snow3hMm'] as num).toDouble(),
      weatherCode: (json['weatherCode'] as num).toInt(),
      condition: json['condition'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String?,
    );

Map<String, dynamic> _$SingleForecastToJson(SingleForecast instance) =>
    <String, dynamic>{
      'forecastAt': instance.forecastAt.toIso8601String(),
      'temperatureC': instance.temperatureC,
      'feelsLikeC': instance.feelsLikeC,
      'humidityPercent': instance.humidityPercent,
      'windSpeedMS': instance.windSpeedMS,
      'precipitationProbability': instance.precipitationProbability,
      'rain3hMm': instance.rain3hMm,
      'snow3hMm': instance.snow3hMm,
      'weatherCode': instance.weatherCode,
      'condition': instance.condition,
      'description': instance.description,
      'icon': instance.icon,
    };
