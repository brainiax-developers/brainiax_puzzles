import 'dart:math';

class SeededRng {
  final Random _random;
  SeededRng(int seed) : _random = Random(seed);
  int nextInt(int max) => _random.nextInt(max);
  double nextDouble() => _random.nextDouble();
}
