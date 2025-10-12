import '../util/kakuro_dictionary.dart';
import '../validation/validator.dart';
import 'kakuro_board.dart';

class KakuroValidator extends PuzzleValidator<KakuroBoard> {
  const KakuroValidator();

  @override
  ValidationSummary validatePuzzle(KakuroBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    for (int i = 0; i < board.cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      final int value = board.values[i];
      if (value < 0 || value > 9) {
        issues.add('value_out_of_range:$i');
      }
    }

    for (final KakuroEntry entry in board.entries) {
      if (!KakuroDictionary.hasCombinations(entry.cells.length, entry.sum)) {
        issues.add('invalid_clue:${entry.id}');
        continue;
      }
      final Set<int> seen = <int>{};
      int partialSum = 0;
      bool invalidDuplicate = false;
      for (final int index in entry.cells) {
        final int value = board.values[index];
        if (value == 0) {
          continue;
        }
        if (value < 1 || value > 9) {
          issues.add('invalid_digit:${entry.id}:$index');
          continue;
        }
        if (!seen.add(value)) {
          invalidDuplicate = true;
          break;
        }
        partialSum += value;
      }
      if (invalidDuplicate) {
        issues.add('duplicate_digit:${entry.id}');
        continue;
      }
      if (partialSum > entry.sum) {
        issues.add('sum_exceeded:${entry.id}');
        continue;
      }
      if (seen.isEmpty) {
        continue;
      }
      final Set<int> combos = KakuroDictionary
          .getCombinations(entry.cells.length, entry.sum)!
          .where((int mask) {
        for (final int digit in seen) {
          if ((mask & _bitFor(digit)) == 0) {
            return false;
          }
        }
        return true;
      }).toSet();
      if (combos.isEmpty) {
        issues.add('incompatible_digits:${entry.id}');
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(KakuroBoard board, KakuroBoard solution) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (board.width != solution.width || board.height != solution.height) {
      issues.add('dimension_mismatch');
    }

    for (int i = 0; i < board.cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      final int original = board.values[i];
      final int solved = solution.values[i];
      if (solved < 1 || solved > 9) {
        issues.add('invalid_digit:$i');
      }
      if (original != 0 && original != solved) {
        issues.add('fixed_mismatch:$i');
      }
    }

    for (final KakuroEntry entry in board.entries) {
      final Set<int> seen = <int>{};
      int sum = 0;
      for (final int index in entry.cells) {
        final int value = solution.values[index];
        if (value < 1 || value > 9 || !seen.add(value)) {
          issues.add('entry_violation:${entry.id}');
          break;
        }
        sum += value;
      }
      if (sum != entry.sum) {
        issues.add('entry_sum:${entry.id}');
      }
    }

    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(KakuroBoard board) {
    for (int i = 0; i < board.cellCount; i++) {
      if (!board.isPlayableIndex(i)) {
        continue;
      }
      final int value = board.values[i];
      if (value < 1 || value > 9) {
        return false;
      }
    }
    for (final KakuroEntry entry in board.entries) {
      final Set<int> seen = <int>{};
      int sum = 0;
      for (final int index in entry.cells) {
        final int value = board.values[index];
        if (value < 1 || value > 9 || !seen.add(value)) {
          return false;
        }
        sum += value;
      }
      if (sum != entry.sum) {
        return false;
      }
    }
    return true;
  }
}

int _bitFor(int digit) => 1 << digit;
