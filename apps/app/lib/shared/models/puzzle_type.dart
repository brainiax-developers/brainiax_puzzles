/// Enum representing different puzzle types available in the app.
enum PuzzleType {
  sudokuClassic('sudoku_classic', 'Classic Sudoku'),
  nonogramMono('nonogram_mono', 'Monochrome Nonogram'),
  kakuroClassic('kakuro_classic', 'Classic Kakuro'),
  slitherlinkLoop('slitherlink_loop', 'Slitherlink Loop'),
  mathdokuClassic('mathdoku_classic', 'Classic Mathdoku'),
  futoshikiClassic('futoshiki_classic', 'Classic Futoshiki'),
  takuzuBinary('takuzu_binary', 'Binary Takuzu');

  const PuzzleType(this.key, this.displayName);

  /// Unique identifier for the puzzle type (matches engine ID).
  final String key;

  /// Human-readable display name for the puzzle type.
  final String displayName;

  /// Get a PuzzleType from its key.
  static PuzzleType? fromKey(String key) {
    for (final type in PuzzleType.values) {
      if (type.key == key) return type;
    }
    return null;
  }

  /// Check if a key represents a valid puzzle type.
  static bool isValidKey(String key) {
    return fromKey(key) != null;
  }

  @override
  String toString() => key;
}
