import '../validation/validator.dart';
import 'takuzu_board.dart';

class TakuzuValidator extends PuzzleValidator<TakuzuBoard> {
  const TakuzuValidator();

  @override
  ValidationSummary validatePuzzle(TakuzuBoard board) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];
    final int limit = board.size ~/ 2;

    for (int row = 0; row < board.size; row++) {
      final _LineAnalysis analysis = _analyseRow(board, row);
      if (analysis.ones > limit) {
        issues.add('Row $row has too many ones');
      }
      if (analysis.zeros > limit) {
        issues.add('Row $row has too many zeros');
      }
      if (analysis.hasTriple) {
        issues.add('Row $row contains three consecutive identical values');
      }
    }

    for (int col = 0; col < board.size; col++) {
      final _LineAnalysis analysis = _analyseColumn(board, col);
      if (analysis.ones > limit) {
        issues.add('Column $col has too many ones');
      }
      if (analysis.zeros > limit) {
        issues.add('Column $col has too many zeros');
      }
      if (analysis.hasTriple) {
        issues.add('Column $col contains three consecutive identical values');
      }
    }

    final Set<String> seenRows = <String>{};
    for (int row = 0; row < board.size; row++) {
      final String key = _rowSignature(board, row);
      if (!key.contains('?')) {
        if (!seenRows.add(key)) {
          issues.add('Duplicate completed row at index $row');
        }
      }
    }

    final Set<String> seenCols = <String>{};
    for (int col = 0; col < board.size; col++) {
      final String key = _columnSignature(board, col);
      if (!key.contains('?')) {
        if (!seenCols.add(key)) {
          issues.add('Duplicate completed column at index $col');
        }
      }
    }

    stopwatch.stop();
    if (issues.isEmpty) {
      return ValidationSummary.success(stopwatch.elapsed);
    }
    return ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(TakuzuBoard board, TakuzuBoard solution) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> issues = <String>[];

    if (board.size != solution.size) {
      issues.add('Solution size mismatch');
    }

    for (int index = 0; index < board.cellCount; index++) {
      if (board.fixed[index] && board.cells[index] != solution.cells[index]) {
        issues.add('Solution differs from fixed cell at index $index');
      }
    }

    if (!solution.isComplete) {
      issues.add('Solution contains empty cells');
    }

    final int limit = solution.size ~/ 2;

    for (int row = 0; row < solution.size; row++) {
      final _LineAnalysis analysis = _analyseRow(solution, row);
      if (analysis.ones != limit || analysis.zeros != limit) {
        issues.add('Row $row is imbalanced');
      }
      if (analysis.hasTriple) {
        issues.add('Row $row contains triple values');
      }
    }

    for (int col = 0; col < solution.size; col++) {
      final _LineAnalysis analysis = _analyseColumn(solution, col);
      if (analysis.ones != limit || analysis.zeros != limit) {
        issues.add('Column $col is imbalanced');
      }
      if (analysis.hasTriple) {
        issues.add('Column $col contains triple values');
      }
    }

    final Set<String> rows = <String>{};
    for (int row = 0; row < solution.size; row++) {
      final String key = _rowSignature(solution, row);
      if (!rows.add(key)) {
        issues.add('Duplicate row detected');
      }
    }

    final Set<String> columns = <String>{};
    for (int col = 0; col < solution.size; col++) {
      final String key = _columnSignature(solution, col);
      if (!columns.add(key)) {
        issues.add('Duplicate column detected');
      }
    }

    stopwatch.stop();
    if (issues.isEmpty) {
      return ValidationSummary.success(stopwatch.elapsed);
    }
    return ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(TakuzuBoard board) {
    if (!board.isComplete) {
      return false;
    }
    final int limit = board.size ~/ 2;
    final Set<String> rows = <String>{};
    final Set<String> cols = <String>{};

    for (int row = 0; row < board.size; row++) {
      final _LineAnalysis analysis = _analyseRow(board, row);
      if (analysis.ones != limit || analysis.zeros != limit || analysis.hasTriple) {
        return false;
      }
      final String key = _rowSignature(board, row);
      if (!rows.add(key)) {
        return false;
      }
    }

    for (int col = 0; col < board.size; col++) {
      final _LineAnalysis analysis = _analyseColumn(board, col);
      if (analysis.ones != limit || analysis.zeros != limit || analysis.hasTriple) {
        return false;
      }
      final String key = _columnSignature(board, col);
      if (!cols.add(key)) {
        return false;
      }
    }

    return true;
  }

  _LineAnalysis _analyseRow(TakuzuBoard board, int row) {
    final List<int> values = <int>[];
    int zeros = 0;
    int ones = 0;
    bool triple = false;
    for (int col = 0; col < board.size; col++) {
      final int value = board.cellAt(row, col);
      values.add(value);
      if (value == 0) {
        zeros++;
      } else if (value == 1) {
        ones++;
      }
      if (col >= 2) {
        final int a = values[col - 2];
        final int b = values[col - 1];
        if (a != TakuzuBoard.emptyValue && a == b && b == value) {
          triple = true;
        }
      }
    }
    return _LineAnalysis(zeros: zeros, ones: ones, hasTriple: triple);
  }

  _LineAnalysis _analyseColumn(TakuzuBoard board, int col) {
    final List<int> values = <int>[];
    int zeros = 0;
    int ones = 0;
    bool triple = false;
    for (int row = 0; row < board.size; row++) {
      final int value = board.cellAt(row, col);
      values.add(value);
      if (value == 0) {
        zeros++;
      } else if (value == 1) {
        ones++;
      }
      if (row >= 2) {
        final int a = values[row - 2];
        final int b = values[row - 1];
        if (a != TakuzuBoard.emptyValue && a == b && b == value) {
          triple = true;
        }
      }
    }
    return _LineAnalysis(zeros: zeros, ones: ones, hasTriple: triple);
  }

  String _rowSignature(TakuzuBoard board, int row) {
    final StringBuffer buffer = StringBuffer();
    for (int col = 0; col < board.size; col++) {
      final int value = board.cellAt(row, col);
      if (value == TakuzuBoard.emptyValue) {
        buffer.write('?');
      } else {
        buffer.write(value);
      }
    }
    return buffer.toString();
  }

  String _columnSignature(TakuzuBoard board, int col) {
    final StringBuffer buffer = StringBuffer();
    for (int row = 0; row < board.size; row++) {
      final int value = board.cellAt(row, col);
      if (value == TakuzuBoard.emptyValue) {
        buffer.write('?');
      } else {
        buffer.write(value);
      }
    }
    return buffer.toString();
  }
}

class _LineAnalysis {
  const _LineAnalysis({
    required this.zeros,
    required this.ones,
    required this.hasTriple,
  });

  final int zeros;
  final int ones;
  final bool hasTriple;
}
