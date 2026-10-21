import 'package:agrilens/shared/utils/shared_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
      ThemeModeController.new,
    );

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  static const _storageKey = 'settings.themeMode';

  @override
  Future<ThemeMode> build() async {
    final storedValue = await getSP(_storageKey);
    return _themeModeFromStorage(storedValue);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    await saveSP(_storageKey, _themeModeToStorage(mode));
  }

  Future<void> useSystemTheme() async {
    await setThemeMode(ThemeMode.system);
  }

  Future<void> useLightTheme() async {
    await setThemeMode(ThemeMode.light);
  }

  Future<void> useDarkTheme() async {
    await setThemeMode(ThemeMode.dark);
  }

  ThemeMode _themeModeFromStorage(String value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String _themeModeToStorage(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
