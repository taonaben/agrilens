import 'dart:math' as math;

import 'package:agrilens/app/weather/components/weather_icon.dart';
import 'package:agrilens/app/weather/components/weather_section_card.dart';
import 'package:agrilens/app/weather/models/single_forecast.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class WeatherDailyForecast extends StatelessWidget {
  const WeatherDailyForecast({
    super.key,
    required this.periods,
    required this.timezoneOffsetSeconds,
  });

  final List<SingleForecast> periods;
  final int timezoneOffsetSeconds;

  @override
  Widget build(BuildContext context) {
    final days = _summarizeDays(periods, timezoneOffsetSeconds);
    final theme = Theme.of(context);

    return WeatherSectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                SolarIconsOutline.calendarMinimalistic,
                size: 19,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text('5-day forecast', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Daily high and low temperatures',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 10),
          if (days.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No daily forecast is available right now.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            ..._rows(context, days),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context, List<_DailyWeather> days) {
    final values = days.expand((day) => [day.low, day.high]);
    final minTemperature = values.reduce(math.min);
    final maxTemperature = values.reduce(math.max);
    final totalRange = math.max(1.0, maxTemperature - minTemperature);
    return [
      for (var index = 0; index < days.length; index++) ...[
        _DailyForecastRow(
          day: days[index],
          isToday: days[index].isToday,
          minTemperature: minTemperature,
          totalRange: totalRange,
        ),
        if (index < days.length - 1)
          Divider(height: 1, color: Theme.of(context).dividerColor),
      ],
    ];
  }
}

class _DailyForecastRow extends StatelessWidget {
  const _DailyForecastRow({
    required this.day,
    required this.isToday,
    required this.minTemperature,
    required this.totalRange,
  });

  final _DailyWeather day;
  final bool isToday;
  final double minTemperature;
  final double totalRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = (day.low - minTemperature) / totalRange;
    final high = (day.high - minTemperature) / totalRange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              isToday ? 'Today' : _weekday(day.date.weekday),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          WeatherIcon(
            weatherCode: day.representative.weatherCode,
            iconCode: day.representative.icon,
            size: 25,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 39,
            child: Text(
              '${day.low.round()}°',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _TemperatureRange(low: low, high: high)),
          const SizedBox(width: 10),
          SizedBox(
            width: 39,
            child: Text(
              '${day.high.round()}°',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemperatureRange extends StatelessWidget {
  const _TemperatureRange({required this.low, required this.high});

  final double low;
  final double high;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = constraints.maxWidth * low.clamp(0.0, 1.0);
        final right = constraints.maxWidth * high.clamp(0.0, 1.0);
        final width = math.max(8.0, right - left);
        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              Positioned(
                left: left.clamp(0.0, constraints.maxWidth - 4),
                width: width.clamp(4.0, constraints.maxWidth),
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.55),
                        theme.colorScheme.primary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyWeather {
  const _DailyWeather({
    required this.date,
    required this.isToday,
    required this.low,
    required this.high,
    required this.representative,
  });

  final DateTime date;
  final bool isToday;
  final double low;
  final double high;
  final SingleForecast representative;
}

List<_DailyWeather> _summarizeDays(
  List<SingleForecast> periods,
  int timezoneOffsetSeconds,
) {
  final grouped = <DateTime, List<SingleForecast>>{};
  for (final period in periods) {
    final local = period.forecastAt.toUtc().add(
      Duration(seconds: timezoneOffsetSeconds),
    );
    final date = DateTime.utc(local.year, local.month, local.day);
    grouped.putIfAbsent(date, () => []).add(period);
  }

  return grouped.entries
      .take(5)
      .map((entry) {
        final dayPeriods = entry.value;
        final representative = dayPeriods.reduce((best, candidate) {
          final bestLocal = best.forecastAt.toUtc().add(
            Duration(seconds: timezoneOffsetSeconds),
          );
          final candidateLocal = candidate.forecastAt.toUtc().add(
            Duration(seconds: timezoneOffsetSeconds),
          );
          final bestDistance = (bestLocal.hour - 12).abs();
          final candidateDistance = (candidateLocal.hour - 12).abs();
          return candidateDistance < bestDistance ? candidate : best;
        });
        return _DailyWeather(
          date: entry.key,
          isToday: entry.key == _localDateNow(timezoneOffsetSeconds),
          low: dayPeriods.map((period) => period.temperatureC).reduce(math.min),
          high: dayPeriods
              .map((period) => period.temperatureC)
              .reduce(math.max),
          representative: representative,
        );
      })
      .toList(growable: false);
}

DateTime _localDateNow(int timezoneOffsetSeconds) {
  final localNow = DateTime.now().toUtc().add(
    Duration(seconds: timezoneOffsetSeconds),
  );
  return DateTime.utc(localNow.year, localNow.month, localNow.day);
}

String _weekday(int weekday) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];
