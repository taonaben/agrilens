import 'single_forecast.dart';

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

  factory WeatherConditions.fromJson(Map<String, dynamic> json) =>
      WeatherConditions(
        observedAt: _date(json, 'observed_at'),
        temperatureC: _number(json, 'temperature_c'),
        feelsLikeC: _number(json, 'feels_like_c'),
        humidityPercent: _integer(json, 'humidity_percent'),
        pressureHpa: _number(json, 'pressure_hpa'),
        windSpeedMS: _number(json, 'wind_speed_m_s'),
        windDirectionDegrees: _optionalInteger(json, 'wind_direction_degrees'),
        cloudinessPercent: _optionalInteger(json, 'cloudiness_percent'),
        visibilityM: _optionalInteger(json, 'visibility_m'),
        weatherCode: _integer(json, 'weather_code'),
        condition: _string(json, 'condition'),
        description: _string(json, 'description'),
        icon: _optionalString(json, 'icon'),
      );
}

/// Response from GET /v1/weather/current.
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

  factory WeatherModel.fromJson(Map<String, dynamic> json) => WeatherModel(
    latitude: _number(json, 'latitude'),
    longitude: _number(json, 'longitude'),
    cityName: _optionalString(json, 'city_name'),
    countryCode: _optionalString(json, 'country_code'),
    timezoneOffsetSeconds: _integer(json, 'timezone_offset_seconds'),
    current: WeatherConditions.fromJson(_object(json, 'current')),
    next24Hours: _forecastList(json, 'next_24_hours'),
  );
}

/// Response from GET /v1/weather/forecast.
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

  factory WeatherForecastModel.fromJson(Map<String, dynamic> json) =>
      WeatherForecastModel(
        latitude: _number(json, 'latitude'),
        longitude: _number(json, 'longitude'),
        cityName: _optionalString(json, 'city_name'),
        countryCode: _optionalString(json, 'country_code'),
        timezoneOffsetSeconds: _integer(json, 'timezone_offset_seconds'),
        forecast: _forecastList(json, 'forecast'),
      );
}

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Invalid or missing $key in weather response.');
}

List<SingleForecast> _forecastList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Invalid or missing $key in weather response.');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is Map<String, dynamic>) return SingleForecast.fromJson(item);
      if (item is Map) {
        return SingleForecast.fromJson(Map<String, dynamic>.from(item));
      }
      throw FormatException('Invalid item in $key weather forecast.');
    }),
  );
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid or missing $key in weather response.');
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('Invalid or missing $key in weather response.');
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('Invalid or missing $key in weather response.');
}

int? _optionalInteger(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is num) return value.toInt();
  throw FormatException('Invalid $key in weather response.');
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Invalid or missing $key in weather response.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Invalid $key in weather response.');
}
