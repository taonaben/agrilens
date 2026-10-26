import 'package:json_annotation/json_annotation.dart';

import 'single_forecast.dart';

part 'weather_model.g.dart';

@JsonSerializable()
class WeatherConditions {
  const WeatherConditions({
    required this.observedAt,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.pressureHpa,
    required this.windSpeedMS,
    this.windDirectionDegrees,
    this.cloudinessPercent,
    this.visibilityM,
    required this.weatherCode,
    required this.condition,
    required this.description,
    this.icon,
  });

  final DateTime observedAt;
  final double temperatureC;
  final double feelsLikeC;
  final int humidityPercent;
  final double pressureHpa;
  final double windSpeedMS;
  final int? windDirectionDegrees;
  final int? cloudinessPercent;
  final int? visibilityM;
  final int weatherCode;
  final String condition;
  final String description;
  final String? icon;

  factory WeatherConditions.fromJson(Map<String, dynamic> json) => _$WeatherConditionsFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherConditionsToJson(this);
}

/// Response from GET /v1/weather/current.
@JsonSerializable()
class WeatherModel {
  const WeatherModel({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.countryCode,
    required this.timezoneOffsetSeconds,
    required this.current,
    required this.next24Hours,
  });

  final double latitude;
  final double longitude;
  final String? cityName;
  final String? countryCode;
  final int timezoneOffsetSeconds;
  final WeatherConditions current;
  final List<SingleForecast> next24Hours;

  factory WeatherModel.fromJson(Map<String, dynamic> json) => _$WeatherModelFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherModelToJson(this);
}

/// Response from GET /v1/weather/forecast.
@JsonSerializable()
class WeatherForecastModel {
  const WeatherForecastModel({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.countryCode,
    required this.timezoneOffsetSeconds,
    required this.forecast,
  });

  final double latitude;
  final double longitude;
  final String? cityName;
  final String? countryCode;
  final int timezoneOffsetSeconds;
  final List<SingleForecast> forecast;

  factory WeatherForecastModel.fromJson(Map<String, dynamic> json) => _$WeatherForecastModelFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherForecastModelToJson(this);
}
