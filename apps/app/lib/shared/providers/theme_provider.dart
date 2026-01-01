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

/// Theme provider service.
class ThemeService {
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

/// Simple theme notifier for managing theme state.
class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier _instance = ThemeNotifier._internal();
  factory ThemeNotifier() => _instance;
  ThemeNotifier._internal();

  ThemeState _state = const ThemeState(mode: AppThemeMode.system, highContrast: false);

  /// Get current state.
  ThemeState get state => _state;

  /// Load theme settings from SharedPreferences.
  Future<void> loadThemeSettings() async {
    final mode = await ThemeService.getThemeMode();
    final highContrast = await ThemeService.getHighContrast();
    
    _state = ThemeState(mode: mode, highContrast: highContrast);
    notifyListeners();
  }

  /// Set the theme mode.
  Future<void> setThemeMode(AppThemeMode mode) async {
    await ThemeService.setThemeMode(mode);
    _state = _state.copyWith(mode: mode);
    notifyListeners();
  }

  /// Toggle high contrast.
  Future<void> toggleHighContrast() async {
    final newValue = !_state.highContrast;
    await ThemeService.setHighContrast(newValue);
    _state = _state.copyWith(highContrast: newValue);
    notifyListeners();
  }

  /// Set high contrast directly.
  Future<void> setHighContrast(bool enabled) async {
    await ThemeService.setHighContrast(enabled);
    _state = _state.copyWith(highContrast: enabled);
    notifyListeners();
  }
}

/// Provider for theme notifier.
final themeNotifierProvider = Provider<ThemeNotifier>((ref) {
  final notifier = ThemeNotifier();
  notifier.loadThemeSettings();
  return notifier;
});

/// Provider for the current theme state.
final themeStateProvider = Provider<ThemeState>((ref) {
  final notifier = ref.watch(themeNotifierProvider);
  return notifier.state;
});

/// Provider for the current theme data.
final currentThemeProvider = Provider<ThemeData>((ref) {
  final themeState = ref.watch(themeStateProvider);
  return themeState.themeData;
});

/// Provider for the current theme mode.
final themeModeProvider = Provider<AppThemeMode>((ref) {
  final themeState = ref.watch(themeStateProvider);
  return themeState.mode;
});

/// Provider for high contrast setting.
final highContrastProvider = Provider<bool>((ref) {
  final themeState = ref.watch(themeStateProvider);
  return themeState.highContrast;
});