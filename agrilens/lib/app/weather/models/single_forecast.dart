import 'package:json_annotation/json_annotation.dart';

part 'single_forecast.g.dart';

@JsonSerializable()
class SingleForecast {
  const SingleForecast({
    required this.forecastAt,
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.windSpeedMS,
    required this.precipitationProbability,
    required this.rain3hMm,
    required this.snow3hMm,
    required this.weatherCode,
    required this.condition,
    required this.description,
    this.icon,
  });

  final DateTime forecastAt;
  final double temperatureC;
  final double feelsLikeC;
  final int humidityPercent;
  final double windSpeedMS;
  final double precipitationProbability;
  final double rain3hMm;
  final double snow3hMm;
  final int weatherCode;
  final String condition;
  final String description;
  final String? icon;

     
  factory SingleForecast.fromJson(Map<String, dynamic> json) => _$SingleForecastFromJson(json);
  Map<String, dynamic> toJson() => _$SingleForecastToJson(this);
}
