import 'package:agrilens/app/weather/components/weather_current_header.dart';
import 'package:agrilens/app/weather/components/weather_daily_forecast.dart';
import 'package:agrilens/app/weather/components/weather_details_card.dart';
import 'package:agrilens/app/weather/components/weather_hourly_forecast.dart';
import 'package:agrilens/app/weather/components/weather_section_card.dart';
import 'package:agrilens/app/weather/components/weather_state_panel.dart';
import 'package:agrilens/app/weather/services/weather_location_service.dart';
import 'package:agrilens/app/weather/state/weather_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

class WeatherPage extends ConsumerStatefulWidget {
  const WeatherPage({super.key});

  @override
  ConsumerState<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends ConsumerState<WeatherPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(weatherProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(weatherProvider);
    final notifier = ref.read(weatherProvider.notifier);
    final width = MediaQuery.sizeOf(context).width;

    if (state.current == null) {
      return WeatherStatePanel(
        isLoading: state.isLoading,
        needsLocation: state.needsLocation,
        error: state.error,
        onRequestLocation: notifier.requestLocationAndLoad,
        onRetry: notifier.load,
        onOpenSettings: _settingsAction(state.error),
      );
    }

    final weather = state.current!;
    final forecast = state.forecast;
    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          width < 600 ? 16 : 28,
          18,
          width < 600 ? 16 : 28,
          28,
        ),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHeading(
                    showTitle: width >= 700,
                    isRefreshing: state.isLoading,
                    onRefresh: notifier.refresh,
                  ),
                  const SizedBox(height: 16),
                  WeatherSectionCard(
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 600 ? 16 : 28,
                      vertical: width < 600 ? 22 : 28,
                    ),
                    child: WeatherCurrentHeader(weather: weather),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    _WeatherErrorBanner(
                      message: state.error!,
                      onRetry: notifier.refresh,
                    ),
                  ],
                  const SizedBox(height: 14),
                  WeatherHourlyForecast(
                    periods: weather.next24Hours,
                    timezoneOffsetSeconds: weather.timezoneOffsetSeconds,
                  ),
                  if (forecast != null) ...[
                    const SizedBox(height: 14),
                    WeatherDailyForecast(
                      periods: forecast.forecast,
                      timezoneOffsetSeconds: forecast.timezoneOffsetSeconds,
                    ),
                  ],
                  const SizedBox(height: 14),
                  WeatherDetailsCard(current: weather.current),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _settingsAction(String? error) {
    const locationService = WeatherLocationService();
    if (error?.contains('blocked') == true) {
      return locationService.openAppSettings;
    }
    if (error?.contains('Turn on device location') == true) {
      return locationService.openLocationSettings;
    }
    return null;
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.showTitle,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final bool showTitle;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle)
                Text('Weather', style: theme.textTheme.headlineSmall),
              if (showTitle) const SizedBox(height: 3),
              Text(
                'Local conditions and forecast',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
        if (isRefreshing)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox.square(
              dimension: 19,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            tooltip: 'Refresh weather',
            onPressed: onRefresh,
            icon: const Icon(SolarIconsOutline.refresh),
          ),
      ],
    );
  }
}

class _WeatherErrorBanner extends StatelessWidget {
  const _WeatherErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            SolarIconsOutline.infoCircle,
            size: 19,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
