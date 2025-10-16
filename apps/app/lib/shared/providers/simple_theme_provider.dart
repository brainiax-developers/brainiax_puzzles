import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Theme mode state.
enum AppThemeMode {
  light,
  dark,
  system,
}

/// Theme state class.
class ThemeState {
  const ThemeState({
    required this.mode,
    required this.highContrast,
  });

  final AppThemeMode mode;
  final bool highContrast;

  /// Get the effective theme mode (resolves system to light/dark).
  AppThemeMode get effectiveMode {
    if (mode == AppThemeMode.system) {
      // For now, default to light. In a real app, you'd check system brightness
      return AppThemeMode.light;
    }
    return mode;
  }

  /// Get the Flutter ThemeData based on current settings.
  ThemeData get themeData {
    final contrast = highContrast ? Contrast.high : Contrast.normal;
    
    switch (effectiveMode) {
      case AppThemeMode.light:
        return AppTheme.light(contrast);
      case AppThemeMode.dark:
        return AppTheme.dark(contrast);
      case AppThemeMode.system:
        return AppTheme.light(contrast); // Fallback
    }
  }

  /// Copy with new values.
  ThemeState copyWith({
    AppThemeMode? mode,
    bool? highContrast,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      highContrast: highContrast ?? this.highContrast,
    );
  }
}

/// Simple theme service.
class SimpleThemeService {
  static const String _themeModeKey = 'theme_mode';
  static const String _highContrastKey = 'high_contrast';

  /// Get the current theme mode from SharedPreferences.
  static Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_themeModeKey) ?? AppThemeMode.system.index;
    return AppThemeMode.values[modeIndex];
  }

  /// Save the theme mode to SharedPreferences.
  static Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  /// Get the high contrast setting from SharedPreferences.
  static Future<bool> getHighContrast() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_highContrastKey) ?? false;
  }

  /// Save the high contrast setting to SharedPreferences.
  static Future<void> setHighContrast(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highContrastKey, enabled);
  }
}

/// Provider for theme state.
final themeStateProvider = FutureProvider<ThemeState>((ref) async {
  final mode = await SimpleThemeService.getThemeMode();
  final highContrast = await SimpleThemeService.getHighContrast();
  return ThemeState(mode: mode, highContrast: highContrast);
});

/// Provider for the current theme data.
final currentThemeProvider = Provider<ThemeData>((ref) {
  final themeState = ref.watch(themeStateProvider).when(
    data: (state) => state,
    loading: () => const ThemeState(mode: AppThemeMode.system, highContrast: false),
    error: (_, __) => const ThemeState(mode: AppThemeMode.system, highContrast: false),
  );
  return themeState.themeData;
});

/// Provider for the current theme mode.
final themeModeProvider = Provider<AppThemeMode>((ref) {
  final themeState = ref.watch(themeStateProvider).when(
    data: (state) => state,
    loading: () => const ThemeState(mode: AppThemeMode.system, highContrast: false),
    error: (_, __) => const ThemeState(mode: AppThemeMode.system, highContrast: false),
  );
  return themeState.mode;
});

/// Provider for high contrast setting.
final highContrastProvider = Provider<bool>((ref) {
  final themeState = ref.watch(themeStateProvider).when(
    data: (state) => state,
    loading: () => const ThemeState(mode: AppThemeMode.system, highContrast: false),
    error: (_, __) => const ThemeState(mode: AppThemeMode.system, highContrast: false),
  );
  return themeState.highContrast;
});