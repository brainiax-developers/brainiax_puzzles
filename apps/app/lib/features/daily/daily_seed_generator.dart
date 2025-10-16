import 'dart:convert';

/// Represents a deterministic daily seed derived from the puzzle type and date.
class DailySeed {
  const DailySeed({
    required this.puzzleTypeKey,
    required this.localDate,
    required this.formattedDate,
    required this.seedStr,
    required this.seed64,
  });

  /// The puzzle type key this seed is generated for.
  final String puzzleTypeKey;

  /// The local date (midnight) used to derive the seed.
  final DateTime localDate;

  /// Date formatted as YYYY-MM-DD in the device's timezone.
  final String formattedDate;

  /// String representation passed into the puzzle engine.
  final String seedStr;

  /// 64-bit deterministic seed compatible with puzzle_core RNG.
  final int seed64;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailySeed &&
          runtimeType == other.runtimeType &&
          puzzleTypeKey == other.puzzleTypeKey &&
          localDate == other.localDate &&
          formattedDate == other.formattedDate &&
          seedStr == other.seedStr &&
          seed64 == other.seed64;

  @override
  int get hashCode =>
      Object.hash(puzzleTypeKey, localDate, formattedDate, seedStr, seed64);
}

typedef _Clock = DateTime Function();

const int _mask64 = 0xffffffffffffffff;
const int _fnvOffsetBasis64 = 0xcbf29ce484222325;
const int _fnvPrime64 = 0x100000001b3;
const int _fallbackSeed64 = 0x1a2b3c4d5e6f7801;

DateTime _systemClock() => DateTime.now();

/// Generates deterministic daily seeds for puzzle types.
class DailySeedGenerator {
  DailySeedGenerator({_Clock? clock}) : _clock = clock ?? _systemClock;

  final _Clock _clock;

  /// Generate the seed for today's puzzle for the given [puzzleTypeKey].
  DailySeed generate(String puzzleTypeKey, {DateTime? date}) {
    final DateTime source = (date ?? _clock()).toLocal();
    final DateTime normalized = DateTime(source.year, source.month, source.day);
    final String formattedDate = _formatDate(normalized);
    final String hashInput = '$puzzleTypeKey$formattedDate';
    final int seed64 = _stableHash64(hashInput);
    final String seedStr = 'daily:$puzzleTypeKey:$formattedDate';

    return DailySeed(
      puzzleTypeKey: puzzleTypeKey,
      localDate: normalized,
      formattedDate: formattedDate,
      seedStr: seedStr,
      seed64: seed64,
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static int _stableHash64(String input) {
    int hash = _fnvOffsetBasis64;
    for (final int byte in utf8.encode(input)) {
      hash = (hash ^ byte) & _mask64;
      hash = (hash * _fnvPrime64) & _mask64;
    }
    if (hash == 0) {
      return _fallbackSeed64;
    }
    return hash & _mask64;
  }
}
