import 'package:agrilens/app/weather/components/weather_section_card.dart';
import 'package:agrilens/app/weather/models/weather_model.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class WeatherDetailsCard extends StatelessWidget {
  const WeatherDetailsCard({super.key, required this.current});

  final WeatherConditions current;

  @override
  Widget build(BuildContext context) {
    final windDirection =
        current.windDirectionDegrees == null
            ? null
            : _compassDirection(current.windDirectionDegrees!);
    final visibility =
        current.visibilityM == null
            ? '—'
            : '${(current.visibilityM! / 1000).toStringAsFixed(1)} km';

    return WeatherSectionCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _DetailTile(
                      icon: SolarIconsOutline.waterdrops,
                      label: 'Humidity',
                      value: '${current.humidityPercent}%',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _DetailTile(
                      icon: SolarIconsOutline.wind,
                      label: 'Wind',
                      value:
                          '${current.windSpeedMS.toStringAsFixed(1)} m/s${windDirection == null ? '' : ' $windDirection'}',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _DetailTile(
                      icon: SolarIconsOutline.thermometer,
                      label: 'Pressure',
                      value: '${current.pressureHpa.round()} hPa',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _DetailTile(
                      icon: SolarIconsOutline.cloud,
                      label: 'Visibility',
                      value: visibility,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _compassDirection(int degrees) {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = degrees % 360;
  return directions[((normalized + 22.5) / 45).floor() % directions.length];
}
