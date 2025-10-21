import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple service to persist haptics preference.
class SimpleHapticsService {
  static const _key = 'haptics_enabled';

  static Future<bool> getHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true; // default to enabled
  }

  static Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

/// Provider exposing persisted haptics setting as a FutureProvider.
final hapticsStateProvider = FutureProvider<bool>((ref) async {
  return await SimpleHapticsService.getHapticsEnabled();
});

/// Synchronous provider for convenient reads (falls back to true while loading).
final hapticsEnabledProvider = Provider<bool>((ref) {
  final state = ref.watch(hapticsStateProvider).when(
    data: (v) => v,
    loading: () => true,
    error: (_, __) => true,
  );
  return state;
});

