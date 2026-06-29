/// Precomputed Run Combination Dictionary for Kakuro.
///
/// Stores valid combinations of digits for a given run length and target sum.
/// Combinations are represented as 9-bit masks where bit 0 is digit 1,
/// and bit 8 is digit 9.
class KakuroDictionary {
  /// Maps [length] -> [sum] -> List of valid combination bitmasks.
  final Map<int, Map<int, List<int>>> _combinations = <int, Map<int, List<int>>>{};

  /// Singleton instance.
  static final KakuroDictionary instance = KakuroDictionary._internal();

  KakuroDictionary._internal() {
    _precompute();
  }

  void _precompute() {
    for (int length = 2; length <= 9; length++) {
      _combinations[length] = <int, List<int>>{};
    }

    // Iterate through all subsets of {1..9}. 2^9 = 512.
    for (int mask = 1; mask < 512; mask++) {
      int length = 0;
      int sum = 0;
      for (int d = 1; d <= 9; d++) {
        if ((mask & (1 << (d - 1))) != 0) {
          length++;
          sum += d;
        }
      }

      // Kakuro runs must have length >= 2.
      if (length >= 2) {
        _combinations[length]!.putIfAbsent(sum, () => <int>[]).add(mask);
      }
    }
  }

  /// Returns a list of valid combination masks for the given [length] and [sum].
  ///
  /// Returns null if no such combinations exist (e.g., impossible sum).
  List<int>? getCombinations(int length, int sum) {
    if (length < 2 || length > 9) {
      return null;
    }
    return _combinations[length]?[sum];
  }

  /// Returns the number of possible combinations for the given run [length] and [sum].
  int getAmbiguity(int length, int sum) {
    final List<int>? combs = getCombinations(length, sum);
    return combs?.length ?? 0;
  }
}
