// apps/app/lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/simple_theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _ContrastTile(),
          _ThemeModeTile(),
          // TODO: add toggles bound to feature flags if desired
        ],
      ),
    );
  }
}

class _ContrastTile extends ConsumerWidget {
  const _ContrastTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highContrast = ref.watch(highContrastProvider);

    return SwitchListTile(
      title: const Text('High contrast'),
      subtitle: const Text('Increase contrast for better visibility'),
      value: highContrast,
      onChanged: (value) async {
        await SimpleThemeService.setHighContrast(value);
        ref.invalidate(themeStateProvider);
      },
    );
  }
}

class _ThemeModeTile extends ConsumerWidget {
  const _ThemeModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return ExpansionTile(
      title: const Text('Theme'),
      subtitle: Text(_getThemeModeText(themeMode)),
      children: [
        RadioListTile<AppThemeMode>(
          title: const Text('Light'),
          value: AppThemeMode.light,
          groupValue: themeMode,
          onChanged: (value) async {
            if (value != null) {
              await SimpleThemeService.setThemeMode(value);
              ref.invalidate(themeStateProvider);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('Dark'),
          value: AppThemeMode.dark,
          groupValue: themeMode,
          onChanged: (value) async {
            if (value != null) {
              await SimpleThemeService.setThemeMode(value);
              ref.invalidate(themeStateProvider);
            }
          },
        ),
        RadioListTile<AppThemeMode>(
          title: const Text('System'),
          value: AppThemeMode.system,
          groupValue: themeMode,
          onChanged: (value) async {
            if (value != null) {
              await SimpleThemeService.setThemeMode(value);
              ref.invalidate(themeStateProvider);
            }
          },
        ),
      ],
    );
  }

  String _getThemeModeText(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light theme';
      case AppThemeMode.dark:
        return 'Dark theme';
      case AppThemeMode.system:
        return 'Follow system setting';
    }
  }
}
