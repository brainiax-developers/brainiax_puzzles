import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service for managing difficulty preferences per puzzle type.
class DifficultyPreferenceService {
  static const String _prefix = 'difficulty_pref_';

  /// Get the preferred difficulty for a puzzle type.
  /// Returns 'Easy' as default if no preference is set.
  static Future<String> getPreferredDifficulty(PuzzleType puzzleType) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${puzzleType.key}';
    return prefs.getString(key) ?? 'Easy';
  }

  /// Set the preferred difficulty for a puzzle type.
  static Future<void> setPreferredDifficulty(PuzzleType puzzleType, String difficulty) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${puzzleType.key}';
    await prefs.setString(key, difficulty);
  }

  /// Get all difficulty preferences.
  static Future<Map<PuzzleType, String>> getAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final preferences = <PuzzleType, String>{};
    
    for (final puzzleType in PuzzleType.values) {
      final key = '$_prefix${puzzleType.key}';
      preferences[puzzleType] = prefs.getString(key) ?? 'Easy';
    }
    
    return preferences;
  }
}
