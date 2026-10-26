// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeatherConditions _$WeatherConditionsFromJson(Map<String, dynamic> json) =>
    WeatherConditions(
      observedAt: DateTime.parse(json['observedAt'] as String),
      temperatureC: (json['temperatureC'] as num).toDouble(),
      feelsLikeC: (json['feelsLikeC'] as num).toDouble(),
      humidityPercent: (json['humidityPercent'] as num).toInt(),
      pressureHpa: (json['pressureHpa'] as num).toDouble(),
      windSpeedMS: (json['windSpeedMS'] as num).toDouble(),
      windDirectionDegrees: (json['windDirectionDegrees'] as num?)?.toInt(),
      cloudinessPercent: (json['cloudinessPercent'] as num?)?.toInt(),
      visibilityM: (json['visibilityM'] as num?)?.toInt(),
      weatherCode: (json['weatherCode'] as num).toInt(),
      condition: json['condition'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String?,
    );

Map<String, dynamic> _$WeatherConditionsToJson(WeatherConditions instance) =>
    <String, dynamic>{
      'observedAt': instance.observedAt.toIso8601String(),
      'temperatureC': instance.temperatureC,
      'feelsLikeC': instance.feelsLikeC,
      'humidityPercent': instance.humidityPercent,
      'pressureHpa': instance.pressureHpa,
      'windSpeedMS': instance.windSpeedMS,
      'windDirectionDegrees': instance.windDirectionDegrees,
      'cloudinessPercent': instance.cloudinessPercent,
      'visibilityM': instance.visibilityM,
      'weatherCode': instance.weatherCode,
      'condition': instance.condition,
      'description': instance.description,
      'icon': instance.icon,
    };

WeatherModel _$WeatherModelFromJson(Map<String, dynamic> json) => WeatherModel(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  cityName: json['cityName'] as String?,
  countryCode: json['countryCode'] as String?,
  timezoneOffsetSeconds: (json['timezoneOffsetSeconds'] as num).toInt(),
  current: WeatherConditions.fromJson(json['current'] as Map<String, dynamic>),
  next24Hours:
      (json['next24Hours'] as List<dynamic>)
          .map((e) => SingleForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$WeatherModelToJson(WeatherModel instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'cityName': instance.cityName,
      'countryCode': instance.countryCode,
      'timezoneOffsetSeconds': instance.timezoneOffsetSeconds,
      'current': instance.current,
      'next24Hours': instance.next24Hours,
    };

WeatherForecastModel _$WeatherForecastModelFromJson(
  Map<String, dynamic> json,
) => WeatherForecastModel(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  cityName: json['cityName'] as String?,
  countryCode: json['countryCode'] as String?,
  timezoneOffsetSeconds: (json['timezoneOffsetSeconds'] as num).toInt(),
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
  'cityName': instance.cityName,
  'countryCode': instance.countryCode,
  'timezoneOffsetSeconds': instance.timezoneOffsetSeconds,
  'forecast': instance.forecast,
};
