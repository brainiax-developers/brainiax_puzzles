import '../generators/kakuro/combos.dart';

/// Legacy compatibility wrapper exposing the older Set-based API.
///
/// New Kakuro code should prefer [KakuroComboTable] directly.
class KakuroDictionary {
  KakuroDictionary._();

  static final KakuroComboTable _table = KakuroComboTable.instance;

  /// Get combinations for a specific length and sum.
  /// Returns null if no combinations exist.
  static Set<int>? getCombinations(int length, int sum) {
    final List<int> combos = _table.combosFor(length, sum);
    if (combos.isEmpty) return null;
    return Set<int>.from(combos);
  }

  /// Get all combinations for a specific length.
  static Map<int, Set<int>>? getCombinationsForLength(int length) {
    final Map<int, List<int>>? legacy = _legacyView(length);
    if (legacy == null) return null;
    return legacy.map((int sum, List<int> masks) => MapEntry(sum, Set<int>.from(masks)));
  }

  /// Check if combinations exist for a specific length and sum.
  static bool hasCombinations(int length, int sum) =>
      _table.hasCombo(length, sum);

  /// Get the total number of combinations for a specific length.
  static int getCombinationCount(int length) =>
      _table.combinationCountForLength(length);

  static Map<int, List<int>>? _legacyView(int length) =>
      _table.viewForLength(length);
}
