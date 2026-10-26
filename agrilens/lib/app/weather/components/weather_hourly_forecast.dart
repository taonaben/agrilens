import 'package:agrilens/app/weather/components/weather_icon.dart';
import 'package:agrilens/app/weather/components/weather_section_card.dart';
import 'package:agrilens/app/weather/models/single_forecast.dart';
import 'package:flutter/material.dart';

class WeatherHourlyForecast extends StatelessWidget {
  const WeatherHourlyForecast({
    super.key,
    required this.periods,
    required this.timezoneOffsetSeconds,
  });

  final List<SingleForecast> periods;
  final int timezoneOffsetSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WeatherSectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Next 24 hours', style: theme.textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            'Temperature and conditions by forecast period',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          if (periods.isEmpty)
            Text(
              'No hourly periods are available right now.',
              style: theme.textTheme.bodyMedium,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < periods.length; index++) ...[
                    _HourlyPeriod(
                      period: periods[index],
                      timezoneOffsetSeconds: timezoneOffsetSeconds,
                    ),
                    if (index < periods.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HourlyPeriod extends StatelessWidget {
  const _HourlyPeriod({
    required this.period,
    required this.timezoneOffsetSeconds,
  });

  final SingleForecast period;
  final int timezoneOffsetSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localTime = period.forecastAt.toUtc().add(
      Duration(seconds: timezoneOffsetSeconds),
    );
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(localTime),
      alwaysUse24HourFormat: true,
    );
    final rainPercent = (period.precipitationProbability * 100).round();

    return SizedBox(
      width: 61,
      child: Column(
        children: [
          Text(timeLabel, style: theme.textTheme.labelMedium),
          const SizedBox(height: 12),
          WeatherIcon(
            weatherCode: period.weatherCode,
            iconCode: period.icon,
            size: 25,
          ),
          const SizedBox(height: 10),
          Text(
            '${period.temperatureC.round()}°',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (rainPercent > 0) ...[
            const SizedBox(height: 3),
            Text(
              '$rainPercent%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
