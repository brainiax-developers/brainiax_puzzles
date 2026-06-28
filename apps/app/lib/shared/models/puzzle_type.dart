/// Enum representing different puzzle types available in the app.
enum PuzzleType {
  sudokuClassic('sudoku_classic', 'Classic Sudoku'),
  kakuro('kakuro', 'Kakuro'),
  nonogramMono('nonogram_mono', 'Monochrome Nonogram'),

  slitherlinkLoop('slitherlink_loop', 'Slitherlink Loop'),
  mathdokuClassic('mathdoku_classic', 'Classic Mathdoku'),
  killerQueens('killer_queens', 'Killer Queens'),
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

  static const List<PuzzleType> comingSoonTypes = [];

  /// Ordered list of puzzle types that participate in Daily Challenges.
  static const List<PuzzleType> dailyChallengeTypes = [
    sudokuClassic,
    kakuro,
    nonogramMono,
    slitherlinkLoop,
    mathdokuClassic,
    killerQueens,
    takuzuBinary,
  ];

  /// Whether this puzzle type is eligible for Daily Challenges.
  bool get isDailyEligible => dailyChallengeTypes.contains(this);

  /// Whether this puzzle type is visible but not currently playable.
  bool get isComingSoon => comingSoonTypes.contains(this);

  /// Whether this puzzle type can currently be started.
  bool get isPlayable => !isComingSoon;

  String? get availabilityBadgeLabel => isComingSoon ? 'Coming Soon' : null;

  String? get unavailableMessage => null;

  @override
  String toString() => key;
}
