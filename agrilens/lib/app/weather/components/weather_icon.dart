import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class WeatherIcon extends StatelessWidget {
  const WeatherIcon({
    super.key,
    required this.weatherCode,
    this.iconCode,
    this.size = 28,
    this.color,
  });

  final int weatherCode;
  final String? iconCode;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
    _iconFor(weatherCode, iconCode),
    size: size,
    color: color ?? Theme.of(context).colorScheme.primary,
  );

  IconData _iconFor(int code, String? iconCode) {
    final isNight = iconCode?.endsWith('n') ?? false;
    if (code >= 200 && code < 300) return SolarIconsOutline.cloudBolt;
    if (code >= 300 && code < 600) return SolarIconsOutline.cloudRain;
    if (code >= 600 && code < 700) return SolarIconsOutline.cloudSnowfall;
    if (code >= 700 && code < 800) return SolarIconsOutline.fog;
    if (code == 800) {
      return isNight ? SolarIconsOutline.moonStars : SolarIconsOutline.sun;
    }
    if (code == 801 || code == 802) {
      return isNight
          ? SolarIconsOutline.cloudyMoon
          : SolarIconsOutline.cloudSun;
    }
    return SolarIconsOutline.clouds;
  }
}
