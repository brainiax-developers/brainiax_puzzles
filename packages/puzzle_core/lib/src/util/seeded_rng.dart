import 'dart:convert';

const int _mask64 = 0xffffffffffffffff;
const int _splitmix64Increment = 0x9e3779b97f4a7c15;

int _rotl64(int value, int shift) {
  final int s = shift & 63;
  return ((value << s) & _mask64) | ((value & _mask64) >> (64 - s));
}

/// Deterministic conversion utilities for seeds.
class Seed {
  Seed._();

  static const int _fnvOffsetBasis = 0xcbf29ce484222325;
  static const int _fnvPrime = 0x100000001b3;

  /// Convert a string into a stable 64-bit seed using FNV-1a hashing.
  static int fromString(String input) {
    int hash = _fnvOffsetBasis;
    final List<int> bytes = utf8.encode(input);
    for (final int byte in bytes) {
      hash = (hash ^ byte) & _mask64;
      hash = (hash * _fnvPrime) & _mask64;
    }
    if (hash == 0) {
      // Avoid the all-zero seed which breaks xoroshiro initialisation.
      hash = 0x1a2b3c4d5e6f7801;
    }
    return hash & _mask64;
  }
}

class _SplitMix64 {
  int _state;

  _SplitMix64(int seed) : _state = seed & _mask64;

  int next() {
    _state = (_state + _splitmix64Increment) & _mask64;
    int z = _state;
    z = (z ^ (z >> 30)) & _mask64;
    z = (z * 0xbf58476d1ce4e5b9) & _mask64;
    z = (z ^ (z >> 27)) & _mask64;
    z = (z * 0x94d049bb133111eb) & _mask64;
    z = (z ^ (z >> 31)) & _mask64;
    return z;
  }
}

/// Deterministic RNG using the xoroshiro128** algorithm.
abstract class SeededRng {
  factory SeededRng(int seed64) = _Xoroshiro128ss;

  static const String rngId = 'xoroshiro128ss';

  /// Generate the next 64-bit integer from the stream.
  int nextInt64();

  /// Generate an integer in the range [0, max).
  int nextIntInRange(int maxExclusive);

  /// Generate an integer in [min, max).
  int randIntRange(int min, int maxExclusive);

  /// Deterministically shuffle the provided list in-place.
  void shuffle<T>(List<T> values);

  /// Return a shuffled copy of the provided items.
  List<T> permute<T>(Iterable<T> items);

  /// Pick a value using integer weights.
  T pickWeighted<T>(List<T> items, List<int> weights);
}

class _Xoroshiro128ss implements SeededRng {
  late int _s0;
  late int _s1;

  _Xoroshiro128ss(int seed64) {
    final _SplitMix64 seeder = _SplitMix64(seed64 == 0 ? 0x1a2b3c4d5e6f7801 : seed64);
    _s0 = seeder.next();
    _s1 = seeder.next();
    if ((_s0 | _s1) == 0) {
      // Guarantee a non-zero state.
      _s1 = 0x9e3779b97f4a7c15;
    }
  }

  @override
  int nextInt64() {
    final int result = (_rotl64((_s0 * 5) & _mask64, 7) * 9) & _mask64;

    final int t = (_s1 << 9) & _mask64;
    _s1 ^= _s0;
    _s0 = _rotl64(_s0, 24) ^ _s1 ^ t;
    _s1 = _rotl64(_s1, 37);

    return result & _mask64;
  }

  @override
  int nextIntInRange(int maxExclusive) {
    if (maxExclusive <= 0) {
      throw ArgumentError.value(maxExclusive, 'maxExclusive', 'Must be > 0');
    }
    final int mask = _calculateBitMask(maxExclusive - 1);
    while (true) {
      final int candidate = nextInt64() & mask;
      if (candidate < maxExclusive) {
        return candidate;
      }
    }
  }

  static int _calculateBitMask(int value) {
    int mask = value;
    mask |= mask >> 1;
    mask |= mask >> 2;
    mask |= mask >> 4;
    mask |= mask >> 8;
    mask |= mask >> 16;
    mask |= mask >> 32;
    return mask;
  }

  @override
  int randIntRange(int min, int maxExclusive) {
    if (min >= maxExclusive) {
      throw ArgumentError('Invalid range [$min, $maxExclusive)');
    }
    final int span = maxExclusive - min;
    final int value = nextIntInRange(span);
    return min + value;
  }

  @override
  void shuffle<T>(List<T> values) {
    for (int i = values.length - 1; i > 0; i--) {
      final int j = nextIntInRange(i + 1);
      final T tmp = values[i];
      values[i] = values[j];
      values[j] = tmp;
    }
  }

  @override
  List<T> permute<T>(Iterable<T> items) {
    final List<T> list = List<T>.from(items);
    shuffle(list);
    return list;
  }

  @override
  T pickWeighted<T>(List<T> items, List<int> weights) {
    if (items.isEmpty || items.length != weights.length) {
      throw ArgumentError('Items and weights must be non-empty and have the same length');
    }
    int total = 0;
    for (final int weight in weights) {
      if (weight < 0) {
        throw ArgumentError('Weights must be non-negative');
      }
      total += weight;
    }
    if (total <= 0) {
      throw ArgumentError('Total weight must be > 0');
    }
    final int target = nextIntInRange(total);
    int cumulative = 0;
    for (int i = 0; i < items.length; i++) {
      cumulative += weights[i];
      if (target < cumulative) {
        return items[i];
      }
    }
    return items.last;
  }
}

/// Deterministic shuffle helper that operates on the provided list.
void shuffleDeterministic<T>(SeededRng rng, List<T> values) => rng.shuffle(values);

/// Deterministically permute the provided iterable.
List<T> permute<T>(SeededRng rng, Iterable<T> items) => rng.permute(items);

/// Pick a weighted value using integer weights.
T pickWeighted<T>(SeededRng rng, List<T> items, List<int> weights) =>
    rng.pickWeighted(items, weights);

/// Generate a random integer in the range [min, max).
int randIntRange(SeededRng rng, int min, int maxExclusive) =>
    rng.randIntRange(min, maxExclusive);
