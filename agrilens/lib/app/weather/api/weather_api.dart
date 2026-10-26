import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/app/weather/models/weather_coordinates.dart';

class WeatherApi {
  const WeatherApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getCurrent(WeatherCoordinates coordinates) =>
      _client.getJson(
        '/v1/weather/current',
        queryParameters: {
          'lat': coordinates.latitude,
          'lon': coordinates.longitude,
        },
      );

  Future<Map<String, dynamic>> getForecast(WeatherCoordinates coordinates) =>
      _client.getJson(
        '/v1/weather/forecast',
        queryParameters: {
          'lat': coordinates.latitude,
          'lon': coordinates.longitude,
        },
      );
}
