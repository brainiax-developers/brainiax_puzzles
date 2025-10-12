class KakuroDictionary {
  KakuroDictionary._();

  static final Map<int, Map<int, Set<int>>> combinations = _build();

  static Map<int, Map<int, Set<int>>> _build() {
    final Map<int, Map<int, Set<int>>> result = <int, Map<int, Set<int>>>{};
    for (int length = 1; length <= 9; length++) {
      result[length] = <int, Set<int>>{};
      _enumerate(length, 1, 0, 0, 0, result[length]!);
    }
    return result;
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
