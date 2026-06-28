import 'package:puzzle_core/puzzle_core.dart';
import 'kakuro_board.dart';

class KakuroValidator extends PuzzleValidator<KakuroBoard> {
  const KakuroValidator();

  @override
  ValidationSummary validatePuzzle(KakuroBoard board) {
    final stopwatch = Stopwatch()..start();
    List<String> issues = [];

    // Check basic layout constraints
    // All white cells must belong to an across run and down run > 1
    for (int r = 0; r < board.height; r++) {
      int runLen = 0;
      for (int c = 0; c < board.width; c++) {
        if (board.isWhite(r * board.width + c)) {
          runLen++;
        } else {
          if (runLen == 1) issues.add('Row $r contains a 1-cell run');
          runLen = 0;
        }
      }
      if (runLen == 1) issues.add('Row $r contains a 1-cell run');
    }

    for (int c = 0; c < board.width; c++) {
      int runLen = 0;
      for (int r = 0; r < board.height; r++) {
        if (board.isWhite(r * board.width + c)) {
          runLen++;
        } else {
          if (runLen == 1) issues.add('Col $c contains a 1-cell run');
          runLen = 0;
        }
      }
      if (runLen == 1) issues.add('Col $c contains a 1-cell run');
    }

    if (issues.isNotEmpty) {
      return ValidationSummary.failure(stopwatch.elapsed, issues);
    }
    return ValidationSummary.success(stopwatch.elapsed);
  }

  @override
  ValidationSummary validateSolution(KakuroBoard board, KakuroBoard solution) {
    final stopwatch = Stopwatch()..start();
    List<String> issues = [];

    // Extract runs and verify sums and uniqueness of digits in runs
    for (int r = 0; r < board.height; r++) {
      for (int c = 0; c < board.width; c++) {
        int index = r * board.width + c;
        if (board.isClue(index)) {
          if (board.acrossClues[index] > 0) {
            int sum = 0;
            int mask = 0;
            for (int c2 = c + 1; c2 < board.width; c2++) {
              int idx2 = r * board.width + c2;
              if (board.isWhite(idx2)) {
                int val = solution.getValue(idx2);
                if (val <= 0 || val > 9) {
                  issues.add('Cell ($r,$c2) has invalid value $val');
                } else {
                  sum += val;
                  if ((mask & (1 << val)) != 0) {
                    issues.add('Duplicate digit $val in across run starting at ($r,$c)');
                  }
                  mask |= (1 << val);
                }
              } else {
                break;
              }
            }
            if (sum != board.acrossClues[index]) {
              issues.add('Across run starting at ($r,$c) has sum $sum, expected ${board.acrossClues[index]}');
            }
          }

          if (board.downClues[index] > 0) {
            int sum = 0;
            int mask = 0;
            for (int r2 = r + 1; r2 < board.height; r2++) {
              int idx2 = r2 * board.width + c;
              if (board.isWhite(idx2)) {
                int val = solution.getValue(idx2);
                if (val <= 0 || val > 9) {
                  if (!issues.contains('Cell ($r2,$c) has invalid value $val')) {
                    issues.add('Cell ($r2,$c) has invalid value $val');
                  }
                } else {
                  sum += val;
                  if ((mask & (1 << val)) != 0) {
                    issues.add('Duplicate digit $val in down run starting at ($r,$c)');
                  }
                  mask |= (1 << val);
                }
              } else {
                break;
              }
            }
            if (sum != board.downClues[index]) {
              issues.add('Down run starting at ($r,$c) has sum $sum, expected ${board.downClues[index]}');
            }
          }
        }
      }
    }

    if (issues.isNotEmpty) {
      return ValidationSummary.failure(stopwatch.elapsed, issues);
    }
    return ValidationSummary.success(stopwatch.elapsed);
  }

  @override
  bool isSolved(KakuroBoard board) {
    for (int i = 0; i < board.cellCount; i++) {
      if (board.isWhite(i) && board.getValue(i) == 0) return false;
    }
    return validateSolution(board, board).isValid;
  }
}
