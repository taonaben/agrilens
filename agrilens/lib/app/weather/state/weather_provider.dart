import 'package:agrilens/app/weather/models/weather_model.dart';
import 'package:agrilens/app/weather/api/weather_api.dart';
import 'package:agrilens/app/weather/models/weather_coordinates.dart';
import 'package:agrilens/app/weather/services/weather_location_service.dart';
import 'package:agrilens/app/weather/services/weather_services.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WeatherState {
  const WeatherState({
    this.isLoading = false,
    this.needsLocation = false,
    this.current,
    this.forecast,
    this.error,
  });

  final bool isLoading;
  final bool needsLocation;
  final WeatherModel? current;
  final WeatherForecastModel? forecast;
  final String? error;

  WeatherState copyWith({
    bool? isLoading,
    bool? needsLocation,
    WeatherModel? current,
    WeatherForecastModel? forecast,
    String? error,
    bool clearError = false,
  }) => WeatherState(
    isLoading: isLoading ?? this.isLoading,
    needsLocation: needsLocation ?? this.needsLocation,
    current: current ?? this.current,
    forecast: forecast ?? this.forecast,
    error: clearError ? null : error ?? this.error,
  );
}

/// Data coordinator for the weather screen; widgets can render this state later.
class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier({
    required WeatherServices weatherServices,
    required WeatherLocationService locationService,
  }) : _weatherServices = weatherServices,
       _locationService = locationService,
       super(const WeatherState());

  final WeatherServices _weatherServices;
  final WeatherLocationService _locationService;

  Future<void> load() async {
    final coordinates = await _locationService.readSaved();
    if (coordinates == null) {
      state = state.copyWith(needsLocation: true, isLoading: false);
      return;
    }
    await refresh(coordinates);
  }

  Future<void> requestLocationAndLoad() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final coordinates = await _locationService.requestAndSave();
      await refresh(coordinates);
    } on WeatherLocationException catch (error) {
      state = state.copyWith(
        isLoading: false,
        needsLocation: true,
        error: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        needsLocation: true,
        error: 'Could not get your location. Please retry.',
      );
    }
  }

  Future<void> refresh([WeatherCoordinates? coordinates]) async {
    final location = coordinates ?? await _locationService.readSaved();
    if (location == null) {
      state = state.copyWith(needsLocation: true, isLoading: false);
      return;
    }

    state = state.copyWith(
      isLoading: true,
      needsLocation: false,
      clearError: true,
    );
    try {
      final values = await Future.wait([
        _weatherServices.getCurrent(location),
        _weatherServices.getForecast(location),
      ]);
      state = state.copyWith(
        isLoading: false,
        current: values[0] as WeatherModel,
        forecast: values[1] as WeatherForecastModel,
      );
    } on ApiRequestException catch (error) {
      state = state.copyWith(isLoading: false, error: error.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error:
            'The weather service returned an invalid response. Please retry.',
      );
    }
  }
}

final weatherProvider = StateNotifierProvider<WeatherNotifier, WeatherState>(
  (ref) => WeatherNotifier(
    weatherServices: WeatherServices(api: WeatherApi(ApiClient())),
    locationService: const WeatherLocationService(),
  ),
);
