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

  @JsonKey(name: 'forecast_at')
  final DateTime forecastAt;
  @JsonKey(name: 'temperature_c')
  final double temperatureC;
  @JsonKey(name: 'feels_like_c')
  final double feelsLikeC;
  @JsonKey(name: 'humidity_percent')
  final int humidityPercent;
  @JsonKey(name: 'wind_speed_m_s')
  final double windSpeedMS;
  @JsonKey(name: 'precipitation_probability')
  final double precipitationProbability;
  @JsonKey(name: 'rain_3h_mm')
  final double rain3hMm;
  @JsonKey(name: 'snow_3h_mm')
  final double snow3hMm;
  @JsonKey(name: 'weather_code')
  final int weatherCode;
  final String condition;
  final String description;
  final String? icon;

  factory SingleForecast.fromJson(Map<String, dynamic> json) =>
      _$SingleForecastFromJson(json);
  Map<String, dynamic> toJson() => _$SingleForecastToJson(this);
}
