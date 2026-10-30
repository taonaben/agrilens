// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeatherConditions _$WeatherConditionsFromJson(Map<String, dynamic> json) =>
    WeatherConditions(
      observedAt: DateTime.parse(json['observed_at'] as String),
      temperatureC: (json['temperature_c'] as num).toDouble(),
      feelsLikeC: (json['feels_like_c'] as num).toDouble(),
      humidityPercent: (json['humidity_percent'] as num).toInt(),
      pressureHpa: (json['pressure_hpa'] as num).toDouble(),
      windSpeedMS: (json['wind_speed_m_s'] as num).toDouble(),
      windDirectionDegrees: (json['wind_direction_degrees'] as num?)?.toInt(),
      cloudinessPercent: (json['cloudiness_percent'] as num?)?.toInt(),
      visibilityM: (json['visibility_m'] as num?)?.toInt(),
      weatherCode: (json['weather_code'] as num).toInt(),
      condition: json['condition'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String?,
    );

Map<String, dynamic> _$WeatherConditionsToJson(WeatherConditions instance) =>
    <String, dynamic>{
      'observed_at': instance.observedAt.toIso8601String(),
      'temperature_c': instance.temperatureC,
      'feels_like_c': instance.feelsLikeC,
      'humidity_percent': instance.humidityPercent,
      'pressure_hpa': instance.pressureHpa,
      'wind_speed_m_s': instance.windSpeedMS,
      'wind_direction_degrees': instance.windDirectionDegrees,
      'cloudiness_percent': instance.cloudinessPercent,
      'visibility_m': instance.visibilityM,
      'weather_code': instance.weatherCode,
      'condition': instance.condition,
      'description': instance.description,
      'icon': instance.icon,
    };

WeatherModel _$WeatherModelFromJson(Map<String, dynamic> json) => WeatherModel(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  cityName: json['city_name'] as String?,
  countryCode: json['country_code'] as String?,
  timezoneOffsetSeconds: (json['timezone_offset_seconds'] as num).toInt(),
  current: WeatherConditions.fromJson(json['current'] as Map<String, dynamic>),
  next24Hours:
      (json['next_24_hours'] as List<dynamic>)
          .map((e) => SingleForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$WeatherModelToJson(WeatherModel instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'city_name': instance.cityName,
      'country_code': instance.countryCode,
      'timezone_offset_seconds': instance.timezoneOffsetSeconds,
      'current': instance.current,
      'next_24_hours': instance.next24Hours,
    };

WeatherForecastModel _$WeatherForecastModelFromJson(
  Map<String, dynamic> json,
) => WeatherForecastModel(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  cityName: json['city_name'] as String?,
  countryCode: json['country_code'] as String?,
  timezoneOffsetSeconds: (json['timezone_offset_seconds'] as num).toInt(),
  forecast:
      (json['forecast'] as List<dynamic>)
          .map((e) => SingleForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$WeatherForecastModelToJson(
  WeatherForecastModel instance,
) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'city_name': instance.cityName,
  'country_code': instance.countryCode,
  'timezone_offset_seconds': instance.timezoneOffsetSeconds,
  'forecast': instance.forecast,
};
