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

  @JsonKey(name: 'observed_at')
  final DateTime observedAt;
  @JsonKey(name: 'temperature_c')
  final double temperatureC;
  @JsonKey(name: 'feels_like_c')
  final double feelsLikeC;
  @JsonKey(name: 'humidity_percent')
  final int humidityPercent;
  @JsonKey(name: 'pressure_hpa')
  final double pressureHpa;
  @JsonKey(name: 'wind_speed_m_s')
  final double windSpeedMS;
  @JsonKey(name: 'wind_direction_degrees')
  final int? windDirectionDegrees;
  @JsonKey(name: 'cloudiness_percent')
  final int? cloudinessPercent;
  @JsonKey(name: 'visibility_m')
  final int? visibilityM;
  @JsonKey(name: 'weather_code')
  final int weatherCode;
  final String condition;
  final String description;
  final String? icon;

  factory WeatherConditions.fromJson(Map<String, dynamic> json) =>
      _$WeatherConditionsFromJson(json);
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
  @JsonKey(name: 'city_name')
  final String? cityName;
  @JsonKey(name: 'country_code')
  final String? countryCode;
  @JsonKey(name: 'timezone_offset_seconds')
  final int timezoneOffsetSeconds;
  final WeatherConditions current;
  @JsonKey(name: 'next_24_hours')
  final List<SingleForecast> next24Hours;

  factory WeatherModel.fromJson(Map<String, dynamic> json) =>
      _$WeatherModelFromJson(json);
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
  @JsonKey(name: 'city_name')
  final String? cityName;
  @JsonKey(name: 'country_code')
  final String? countryCode;
  @JsonKey(name: 'timezone_offset_seconds')
  final int timezoneOffsetSeconds;
  final List<SingleForecast> forecast;

  factory WeatherForecastModel.fromJson(Map<String, dynamic> json) =>
      _$WeatherForecastModelFromJson(json);
  Map<String, dynamic> toJson() => _$WeatherForecastModelToJson(this);
}
