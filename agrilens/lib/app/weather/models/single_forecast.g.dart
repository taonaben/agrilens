// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'single_forecast.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SingleForecast _$SingleForecastFromJson(Map<String, dynamic> json) =>
    SingleForecast(
      forecastAt: DateTime.parse(json['forecast_at'] as String),
      temperatureC: (json['temperature_c'] as num).toDouble(),
      feelsLikeC: (json['feels_like_c'] as num).toDouble(),
      humidityPercent: (json['humidity_percent'] as num).toInt(),
      windSpeedMS: (json['wind_speed_m_s'] as num).toDouble(),
      precipitationProbability:
          (json['precipitation_probability'] as num).toDouble(),
      rain3hMm: (json['rain_3h_mm'] as num).toDouble(),
      snow3hMm: (json['snow_3h_mm'] as num).toDouble(),
      weatherCode: (json['weather_code'] as num).toInt(),
      condition: json['condition'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String?,
    );

Map<String, dynamic> _$SingleForecastToJson(SingleForecast instance) =>
    <String, dynamic>{
      'forecast_at': instance.forecastAt.toIso8601String(),
      'temperature_c': instance.temperatureC,
      'feels_like_c': instance.feelsLikeC,
      'humidity_percent': instance.humidityPercent,
      'wind_speed_m_s': instance.windSpeedMS,
      'precipitation_probability': instance.precipitationProbability,
      'rain_3h_mm': instance.rain3hMm,
      'snow_3h_mm': instance.snow3hMm,
      'weather_code': instance.weatherCode,
      'condition': instance.condition,
      'description': instance.description,
      'icon': instance.icon,
    };
