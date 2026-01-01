/// Enum representing different puzzle play modes.
enum PuzzleMode {
  daily('daily', 'Daily Challenge'),
  random('random', 'Random Puzzle');

  const PuzzleMode(this.key, this.displayName);

  /// Unique identifier for the puzzle mode.
  final String key;

  /// Human-readable display name for the puzzle mode.
  final String displayName;

  /// Get a PuzzleMode from its key.
  static PuzzleMode? fromKey(String key) {
    for (final mode in PuzzleMode.values) {
      if (mode.key == key) return mode;
    }
    return null;
  }

  /// Check if a key represents a valid puzzle mode.
  static bool isValidKey(String key) {
    return fromKey(key) != null;
  }

  @override
  String toString() => key;
}
