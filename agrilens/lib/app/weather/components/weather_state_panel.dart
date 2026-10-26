import 'package:agrilens/shared/components/custom_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

class WeatherStatePanel extends StatelessWidget {
  const WeatherStatePanel({
    super.key,
    required this.isLoading,
    required this.needsLocation,
    this.error,
    this.onRequestLocation,
    this.onRetry,
    this.onOpenSettings,
    this.onRefresh,
  });

  final bool isLoading;
  final bool needsLocation;
  final String? error;
  final VoidCallback? onRequestLocation;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocationRequest = needsLocation;
    final title =
        isLocationRequest
            ? 'Weather for your area'
            : error == null
            ? 'Loading local weather'
            : 'Weather is unavailable';
    final message =
        isLocationRequest
            ? 'Allow approximate location to get current conditions and the five-day forecast for where you are. Your coordinates are sent only with weather requests.'
            : error ?? 'Fetching the latest conditions and forecast.';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLocationRequest
                      ? SolarIconsOutline.mapPoint
                      : SolarIconsOutline.cloudSun,
                  size: 30,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              if (isLoading)
                const SizedBox.square(
                  dimension: 24,
                  child: CustomProgressIndicator()
                )
              else if (isLocationRequest)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRequestLocation,
                      icon: const Icon(SolarIconsOutline.mapPoint),
                      label: const Text('Use my location'),
                    ),
                    if (onOpenSettings != null)
                      OutlinedButton(
                        onPressed: onOpenSettings,
                        child: const Text('Open app settings'),
                      ),
                  ],
                )
              else if (error != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(SolarIconsOutline.refresh),
                      label: const Text('Try again'),
                    ),
                    if (onOpenSettings != null)
                      OutlinedButton(
                        onPressed: onOpenSettings,
                        child: const Text('Open app settings'),
                      ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(SolarIconsOutline.refresh),
                  label: const Text('Refresh'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
