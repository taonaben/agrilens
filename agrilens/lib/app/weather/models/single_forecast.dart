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

  factory SingleForecast.fromJson(Map<String, dynamic> json) => SingleForecast(
    forecastAt: _date(json, 'forecast_at'),
    temperatureC: _number(json, 'temperature_c'),
    feelsLikeC: _number(json, 'feels_like_c'),
    humidityPercent: _integer(json, 'humidity_percent'),
    windSpeedMS: _number(json, 'wind_speed_m_s'),
    precipitationProbability: _number(json, 'precipitation_probability'),
    rain3hMm: _number(json, 'rain_3h_mm'),
    snow3hMm: _number(json, 'snow_3h_mm'),
    weatherCode: _integer(json, 'weather_code'),
    condition: _string(json, 'condition'),
    description: _string(json, 'description'),
    icon: _optionalString(json, 'icon'),
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
