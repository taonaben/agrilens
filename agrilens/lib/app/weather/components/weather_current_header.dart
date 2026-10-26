import 'package:agrilens/app/weather/components/weather_icon.dart';
import 'package:agrilens/app/weather/models/weather_model.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class WeatherCurrentHeader extends StatelessWidget {
  const WeatherCurrentHeader({super.key, required this.weather});

  final WeatherModel weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final city = [
      weather.cityName,
      weather.countryCode,
    ].where((value) => value != null && value.isNotEmpty).join(', ');
    final localObservedAt = weather.current.observedAt.toUtc().add(
      Duration(seconds: weather.timezoneOffsetSeconds),
    );
    final time = TimeOfDay.fromDateTime(localObservedAt);
    final updatedLabel = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(time);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              SolarIconsOutline.mapPoint,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                city.isEmpty ? 'Your local weather' : city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        WeatherIcon(
          weatherCode: weather.current.weatherCode,
          iconCode: weather.current.icon,
          size: 42,
        ),
        const SizedBox(height: 4),
        Text(
          '${weather.current.temperatureC.round()}°',
          style: text.displayLarge?.copyWith(
            fontSize: 76,
            height: 1.08,
            fontWeight: FontWeight.w400,
            letterSpacing: -3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          weather.current.condition,
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          weather.current.description,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _SummaryMetric(
              icon: SolarIconsOutline.temperature,
              label: 'Feels like ${weather.current.feelsLikeC.round()}°',
            ),
            _SummaryMetric(
              icon: SolarIconsOutline.clockCircle,
              label: 'Updated $updatedLabel',
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.hintColor),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}
