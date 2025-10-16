class SoftTimeoutException implements Exception {
  final int iterations;
  const SoftTimeoutException(this.iterations);

  @override
  String toString() => 'SoftTimeoutException(iterations: $iterations)';
}

class SoftTimeout {
  final int maxIterations;
  int _count = 0;

  SoftTimeout({required this.maxIterations}) : assert(maxIterations > 0);

  void tick([int amount = 1]) {
    _count += amount;
    if (_count > maxIterations) {
      throw SoftTimeoutException(_count);
    }
  }

  int get count => _count;
}
