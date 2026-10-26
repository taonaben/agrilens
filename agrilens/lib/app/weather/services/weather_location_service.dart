import 'dart:async';

import 'package:agrilens/app/weather/models/weather_coordinates.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeatherLocationFailure { denied, deniedForever, serviceDisabled, timeout }

class WeatherLocationException implements Exception {
  const WeatherLocationException(this.failure);

  final WeatherLocationFailure failure;

  String get message => switch (failure) {
    WeatherLocationFailure.denied =>
      'Location access was declined. You can allow it when you are ready.',
    WeatherLocationFailure.deniedForever =>
      'Location access is blocked for AgriLens. Enable it in your device settings.',
    WeatherLocationFailure.serviceDisabled =>
      'Turn on device location services to get local weather.',
    WeatherLocationFailure.timeout =>
      'Could not get your location in time. Check your signal and retry.',
  };

  @override
  String toString() => message;
}

/// Requests foreground location only when the user explicitly opts in.
class WeatherLocationService {
  const WeatherLocationService();

  static const _latitudeKey = 'weather_location_latitude';
  static const _longitudeKey = 'weather_location_longitude';

  Future<WeatherCoordinates?> readSaved() async {
    final preferences = await SharedPreferences.getInstance();
    final latitude = preferences.getDouble(_latitudeKey);
    final longitude = preferences.getDouble(_longitudeKey);
    if (latitude == null || longitude == null) return null;
    return WeatherCoordinates(latitude: latitude, longitude: longitude);
  }

  Future<WeatherCoordinates> requestAndSave() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const WeatherLocationException(
        WeatherLocationFailure.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const WeatherLocationException(WeatherLocationFailure.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const WeatherLocationException(
        WeatherLocationFailure.deniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final coordinates = WeatherCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_latitudeKey, coordinates.latitude);
      await preferences.setDouble(_longitudeKey, coordinates.longitude);
      return coordinates;
    } on TimeoutException {
      throw const WeatherLocationException(WeatherLocationFailure.timeout);
    }
  }

  Future<void> clearSaved() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_latitudeKey);
    await preferences.remove(_longitudeKey);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
