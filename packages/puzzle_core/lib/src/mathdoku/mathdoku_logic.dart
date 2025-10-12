import 'mathdoku_board.dart';

/// Compute whether [values] satisfy the cage [operation] and [target].
bool mathdokuMatches(MathdokuOperation operation, int target, List<int> values) {
  switch (operation) {
    case MathdokuOperation.equality:
      return values.length == 1 && values.first == target;
    case MathdokuOperation.addition:
      return values.reduce((int a, int b) => a + b) == target;
    case MathdokuOperation.multiplication:
      return values.reduce((int a, int b) => a * b) == target;
    case MathdokuOperation.subtraction:
      return _checkOrdered(values, target, (int a, int b) => a - b,
          allowIntermediateZero: false, requirePositiveResult: true);
    case MathdokuOperation.division:
      return _checkDivision(values, target);
  }
}

/// Determine all subtraction targets achievable with some ordering of [values].
Set<int> mathdokuSubtractionTargets(List<int> values) {
  final Set<int> results = <int>{};
  _forEachPermutation(values, (List<int> perm) {
    int result = perm.first;
    for (int i = 1; i < perm.length; i++) {
      result -= perm[i];
    }
    if (result > 0) {
      results.add(result);
    }
  });
  return results;
}

/// Determine all division targets achievable with some ordering of [values].
Set<int> mathdokuDivisionTargets(List<int> values) {
  final Set<int> results = <int>{};
  _forEachPermutation(values, (List<int> perm) {
    int result = perm.first;
    bool valid = true;
    for (int i = 1; i < perm.length; i++) {
      final int divisor = perm[i];
      if (divisor == 0 || result % divisor != 0) {
        valid = false;
        break;
      }
      result ~/= divisor;
    }
    if (valid && result > 0) {
      results.add(result);
    }
  });
  return results;
}

bool _checkDivision(List<int> values, int target) {
  bool satisfied = false;
  _forEachPermutation(values, (List<int> perm) {
    int result = perm.first;
    bool valid = true;
    for (int i = 1; i < perm.length; i++) {
      final int divisor = perm[i];
      if (divisor == 0 || result % divisor != 0) {
        valid = false;
        break;
      }
      result ~/= divisor;
    }
    if (valid && result == target) {
      satisfied = true;
    }
  });
  return satisfied;
}

bool _checkOrdered(
  List<int> values,
  int target,
  int Function(int, int) combine, {
  bool allowIntermediateZero = true,
  bool requirePositiveResult = false,
}) {
  bool satisfied = false;
  _forEachPermutation(values, (List<int> perm) {
    int result = perm.first;
    bool valid = true;
    for (int i = 1; i < perm.length; i++) {
      result = combine(result, perm[i]);
      if (!allowIntermediateZero && result <= 0) {
        valid = false;
        break;
      }
    }
    if (!valid) {
      return;
    }
    if (requirePositiveResult && result <= 0) {
      return;
    }
    if (result == target) {
      satisfied = true;
    }
  });
  return satisfied;
}

typedef _PermutationCallback = void Function(List<int> permutation);

void _forEachPermutation(List<int> values, _PermutationCallback fn) {
  final List<int> sorted = List<int>.from(values)..sort();
  final List<bool> used = List<bool>.filled(sorted.length, false);
  final List<int> current = List<int>.filled(sorted.length, 0);

  void backtrack(int depth) {
    if (depth == sorted.length) {
      fn(List<int>.from(current));
      return;
    }
    for (int i = 0; i < sorted.length; i++) {
      if (used[i]) {
        continue;
      }
      if (i > 0 && sorted[i] == sorted[i - 1] && !used[i - 1]) {
        continue;
      }
      used[i] = true;
      current[depth] = sorted[i];
      backtrack(depth + 1);
      used[i] = false;
    }
  }

  backtrack(0);
}
