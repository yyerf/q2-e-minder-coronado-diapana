import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

// Theme Mode Provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  void _loadThemeMode() {
    final savedMode = AppConfig.getThemeMode();
    switch (savedMode) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }
    await AppConfig.setThemeMode(modeString);
  }
}

// Connectivity Provider
final connectivityProvider = StateProvider<bool>((ref) => true);

// Loading State Provider
final loadingProvider = StateProvider<bool>((ref) => false);
