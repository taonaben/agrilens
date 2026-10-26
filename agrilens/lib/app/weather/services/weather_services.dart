import 'package:agrilens/app/weather/api/weather_api.dart';
import 'package:agrilens/app/weather/models/weather_model.dart';
import 'package:agrilens/app/weather/models/weather_coordinates.dart';

class WeatherServices {
  const WeatherServices({required WeatherApi api}) : _api = api;

  final WeatherApi _api;

  Future<WeatherModel> getCurrent(WeatherCoordinates coordinates) async =>
      WeatherModel.fromJson(await _api.getCurrent(coordinates));

  Future<WeatherForecastModel> getForecast(
    WeatherCoordinates coordinates,
  ) async => WeatherForecastModel.fromJson(await _api.getForecast(coordinates));
}
