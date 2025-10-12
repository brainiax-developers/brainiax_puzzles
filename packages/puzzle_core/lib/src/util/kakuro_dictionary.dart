class KakuroDictionary {
  KakuroDictionary._();

  static final Map<int, Map<int, Set<int>>> _combinations = <int, Map<int, Set<int>>>{};
  static bool _initialized = false;

  /// Get combinations for a specific length and sum.
  /// Returns null if no combinations exist.
  static Set<int>? getCombinations(int length, int sum) {
    _ensureInitialized();
    return _combinations[length]?[sum];
  }

  /// Get all combinations for a specific length.
  static Map<int, Set<int>>? getCombinationsForLength(int length) {
    _ensureInitialized();
    return _combinations[length];
  }

  /// Check if combinations exist for a specific length and sum.
  static bool hasCombinations(int length, int sum) {
    _ensureInitialized();
    return _combinations[length]?[sum] != null;
  }

  /// Get the total number of combinations for a specific length.
  static int getCombinationCount(int length) {
    _ensureInitialized();
    return _combinations[length]?.length ?? 0;
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      _build();
      _initialized = true;
    }
  }

  static void _build() {
    for (int length = 1; length <= 9; length++) {
      _combinations[length] = <int, Set<int>>{};
      _enumerate(length, 1, 0, 0, 0, _combinations[length]!);
    }
  }

  static void _enumerate(
    int remaining,
    int nextDigit,
    int currentMask,
    int currentSum,
    int depth,
    Map<int, Set<int>> bucket,
  ) {
    if (remaining == 0) {
      bucket.putIfAbsent(currentSum, () => <int>{}).add(currentMask);
      return;
    }
    if (nextDigit > 9) {
      return;
    }
    for (int digit = nextDigit; digit <= 9; digit++) {
      final int mask = currentMask | (1 << digit);
      _enumerate(
        remaining - 1,
        digit + 1,
        mask,
        currentSum + digit,
        depth + 1,
        bucket,
      );
    }
  }
}
