/// Precomputed Kakuro digit combinations indexed by (length, sum).
///
/// Each combination is stored as a bitmask over digits 1..9 where bit `d`
/// indicates that digit `d` is present (e.g. mask `0b0000001110` represents
/// the set {1,2,3}).
class KakuroComboTable {
  KakuroComboTable._(this._combos);

  final Map<int, Map<int, List<int>>> _combos;

  static final KakuroComboTable instance = KakuroComboTable._(_build());

  /// Returns the cached list of bitmask combinations for [length] and [sum].
  /// An empty list is returned when no combinations exist.
  List<int> combosFor(int length, int sum) {
    final Map<int, List<int>>? bySum = _combos[length];
    if (bySum == null) {
      return const <int>[];
    }
    return bySum[sum] ?? const <int>[];
  }

  /// True if at least one combination exists for [length] and [sum].
  bool hasCombo(int length, int sum) => combosFor(length, sum).isNotEmpty;

  /// Total number of sums available for [length].
  int combinationCountForLength(int length) =>
      _combos[length]?.length ?? 0;

  /// Returns the internal (length -> sum -> combos) view for legacy adapters.
  Map<int, List<int>>? viewForLength(int length) => _combos[length];

  static Map<int, Map<int, List<int>>> _build() {
    final Map<int, Map<int, List<int>>> table =
        <int, Map<int, List<int>>>{};
    for (int length = 1; length <= 9; length++) {
      table[length] = <int, List<int>>{};
      _enumerate(
        remaining: length,
        nextDigit: 1,
        currentMask: 0,
        currentSum: 0,
        sink: table[length]!,
      );
    }
    return table;
  }

  static void _enumerate({
    required int remaining,
    required int nextDigit,
    required int currentMask,
    required int currentSum,
    required Map<int, List<int>> sink,
  }) {
    if (remaining == 0) {
      sink.putIfAbsent(currentSum, () => <int>[]).add(currentMask);
      return;
    }
    if (nextDigit > 9) {
      return;
    }
    for (int digit = nextDigit; digit <= 9; digit++) {
      final int mask = currentMask | (1 << digit);
      _enumerate(
        remaining: remaining - 1,
        nextDigit: digit + 1,
        currentMask: mask,
        currentSum: currentSum + digit,
        sink: sink,
      );
    }
  }
}

/// Convenience helpers for working with digit bitmasks.
class KakuroMask {
  KakuroMask._();

  static const int allDigits = 0x3fe; // bits 1..9

  static int bit(int digit) => 1 << digit;

  static int popcount(int mask) {
    int value = mask;
    int count = 0;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }

  static Iterable<int> digits(int mask) sync* {
    for (int digit = 1; digit <= 9; digit++) {
      if ((mask & bit(digit)) != 0) {
        yield digit;
      }
    }
  }

  static int lowestDigit(int mask) {
    for (int digit = 1; digit <= 9; digit++) {
      if ((mask & bit(digit)) != 0) {
        return digit;
      }
    }
    return 0;
  }
}
