// apps/app/lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/providers/simple_theme_provider.dart';
import '../../shared/providers/haptics_provider.dart';

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
          _HapticsTile(),
          _PrivacyPolicyTile(),
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

class _HapticsTile extends ConsumerWidget {
  const _HapticsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(hapticsEnabledProvider);

    return SwitchListTile(
      title: const Text('Haptic feedback'),
      subtitle: const Text('Enable light vibrations for actions'),
      value: enabled,
      onChanged: (value) async {
        await SimpleHapticsService.setHapticsEnabled(value);
        // Refresh provider state
        ref.invalidate(hapticsStateProvider);
      },
    );
  }
}

class _PrivacyPolicyTile extends StatelessWidget {
  const _PrivacyPolicyTile();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Privacy Policy'),
      trailing: const Icon(Icons.open_in_new),
      onTap: () async {
        final url = Uri.parse('https://brainiax-developers.github.io/brainiax_puzzles_privacy/');
        try {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open privacy policy')),
            );
          }
        }
      },
    );
  }
}