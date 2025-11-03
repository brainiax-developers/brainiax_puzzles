import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/nonogram.dart';
import '../util/seeded_rng.dart';
import 'nonogram_board.dart';
import 'nonogram_solver.dart';

class NonogramGenerator extends PuzzleGenerator<NonogramBoard> {
  const NonogramGenerator({
    this.maxUniquenessAttempts = 64,
    this.logicSolver = const NonogramSolver(),
  });

  final int maxUniquenessAttempts;
  final NonogramSolver logicSolver;

  @override
  PuzzleGenerationResult<NonogramBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (!_supportedSize(width, height)) {
      throw ArgumentError('Unsupported nonogram size: ${width}x$height');
    }

    final int cellCount = width * height;
    // Build a target solution bitmap influenced by requested difficulty to better
    // control average clue lengths and alternations for easier levels.
    List<int> solution = _deriveBitmapForDifficulty(
      context.rng,
      width,
      height,
      context.difficulty.level.toLowerCase(),
    );
    if (!_hasAnyFilled(solution)) {
      solution = _injectDeterministicPattern(width, height);
    }

    final List<int> toggleOrder = context.rng.permute(
      List<int>.generate(cellCount, (int index) => index),
    );

    for (int attempt = 0; attempt < maxUniquenessAttempts; attempt++) {
      final PuzzleGenerationResult<NonogramBoard>? attemptResult = _attemptSolution(
        solution,
        width,
        height,
        context,
        attempt: attempt + 1,
      );
      if (attemptResult != null) {
        return attemptResult;
      }

      if (attempt >= toggleOrder.length) {
        break;
      }

      final int index = toggleOrder[attempt];
      solution[index] = solution[index] == NonogramLineSolver.filled
          ? NonogramLineSolver.empty
          : NonogramLineSolver.filled;
    }

    final PuzzleGenerationResult<NonogramBoard>? fallbackResult = _attemptSolution(
      _fallbackPattern(width, height),
      width,
      height,
      context,
      attempt: maxUniquenessAttempts + 1,
    );
    if (fallbackResult != null) {
      return fallbackResult;
    }

    throw StateError('Unable to generate unique nonogram for seed ${context.seedStr}');
  }

  List<int> _deriveBitmapForDifficulty(
    SeededRng rng,
    int width,
    int height,
    String level,
  ) {
    switch (level) {
      case 'easy':
        return _blockyBitmap(rng, width, height, blocks: 3, minSize: 3, maxSize: 6);
      case 'medium':
        return _blockyBitmap(rng, width, height, blocks: 4, minSize: 2, maxSize: 5);
      default:
        return _deriveBitmap(rng, width, height);
    }
  }

  List<int> _blockyBitmap(
    SeededRng rng,
    int width,
    int height, {
    required int blocks,
    required int minSize,
    required int maxSize,
  }) {
    final List<int> bitmap =
        List<int>.filled(width * height, NonogramLineSolver.empty);
    for (int i = 0; i < blocks; i++) {
      final int w = rng.randIntRange(minSize, (maxSize + 1).clamp(minSize, width));
      final int h = rng.randIntRange(minSize, (maxSize + 1).clamp(minSize, height));
      final int x0 = rng.randIntRange(0, (width - w + 1).clamp(0, width));
      final int y0 = rng.randIntRange(0, (height - h + 1).clamp(0, height));
      for (int y = y0; y < y0 + h && y < height; y++) {
        for (int x = x0; x < x0 + w && x < width; x++) {
          bitmap[y * width + x] = NonogramLineSolver.filled;
        }
      }
    }

    // Light random noise to avoid triviality, but keep fragmentation low.
    final int flips = (width * height) ~/ 12; // ~8% cells
    for (int k = 0; k < flips; k++) {
      final int idx = rng.randIntRange(0, width * height);
      // 2/3 chance to keep as is to favor larger contiguous areas
      if (rng.nextIntInRange(3) == 0) {
        bitmap[idx] =
            bitmap[idx] == NonogramLineSolver.filled ? NonogramLineSolver.empty : NonogramLineSolver.filled;
      }
    }
    return bitmap;
  }

  bool _supportedSize(int width, int height) {
    return (width == 10 && height == 10) || (width == 15 && height == 15);
  }

  List<int> _deriveBitmap(SeededRng rng, int width, int height) {
    final int cellCount = width * height;
    final int fillMin = (cellCount * 25) ~/ 100;
    final int fillMax = (cellCount * 65) ~/ 100;
    int remainingFilled = rng.randIntRange(fillMin, fillMax + 1);

    final List<int> bitmap = List<int>.filled(cellCount, NonogramLineSolver.empty);
    final List<int> order = rng.permute(
      List<int>.generate(cellCount, (int index) => index),
    );
    for (int i = 0; i < order.length; i++) {
      final int index = order[i];
      if (remainingFilled <= 0) {
        break;
      }
      final int remainingCells = cellCount - i;
      if (remainingFilled >= remainingCells) {
        bitmap[index] = NonogramLineSolver.filled;
        remainingFilled--;
        continue;
      }
      final bool chooseFilled = rng.nextIntInRange(100) < 55;
      if (chooseFilled) {
        bitmap[index] = NonogramLineSolver.filled;
        remainingFilled--;
      }
    }
    return bitmap;
  }

  bool _hasAnyFilled(List<int> bitmap) {
    for (final int value in bitmap) {
      if (value == NonogramLineSolver.filled) {
        return true;
      }
    }
    return false;
  }

  List<int> _injectDeterministicPattern(int width, int height) {
    final List<int> bitmap =
        List<int>.filled(width * height, NonogramLineSolver.empty);
    final int diagonal = width < height ? width : height;
    for (int i = 0; i < diagonal; i++) {
      bitmap[i * width + i] = NonogramLineSolver.filled;
    }
    return bitmap;
  }

  bool _matchesSolution(List<int?> solvedCells, List<int> solution) {
    if (solvedCells.length != solution.length) {
      return false;
    }
    for (int i = 0; i < solvedCells.length; i++) {
      if (solvedCells[i] != solution[i]) {
        return false;
      }
    }
    return true;
  }

  PuzzleGenerationResult<NonogramBoard>? _attemptSolution(
    List<int> solution,
    int width,
    int height,
    GeneratorContext context, {
    required int attempt,
  }) {
    final List<List<int>> rowClues = _cluesForRows(solution, width, height);
    final List<List<int>> columnClues = _cluesForColumns(solution, width, height);
    final NonogramBoard puzzle = NonogramBoard.empty(
      width: width,
      height: height,
      rowClues: rowClues,
      columnClues: columnClues,
    );

    final SolverResult<NonogramBoard> result = logicSolver.solve(
      puzzle,
      SolverContext(
        rng: SeededRng(context.seed64 ^ 0x41b29d38b14e5c03),
        maxSolutions: 2,
      ),
    );

    if (result.isUnique && result.solutions.isNotEmpty) {
      final NonogramBoard solved = result.solutions.first;
      if (_matchesSolution(solved.cells, solution)) {
        return PuzzleGenerationResult<NonogramBoard>(
          board: puzzle,
          snapshot: GenerationSnapshot(
            telemetry: <String, Object?>{
              'attempts': attempt,
              'fillRatio': _fillRatio(solution),
              'solverTelemetry': result.telemetry,
            },
          ),
        );
      }
    }

    return null;
  }

  List<int> _fallbackPattern(int width, int height) {
    final List<int> bitmap =
        List<int>.filled(width * height, NonogramLineSolver.empty);
    final int limit = width < height ? width : height;
    for (int row = 0; row < height; row++) {
      final int run = (row < limit) ? (row + 1) : limit;
      for (int col = 0; col < run && col < width; col++) {
        bitmap[row * width + col] = NonogramLineSolver.filled;
      }
    }
    return bitmap;
  }

  double _fillRatio(List<int> bitmap) {
    if (bitmap.isEmpty) {
      return 0.0;
    }
    int filled = 0;
    for (final int value in bitmap) {
      if (value == NonogramLineSolver.filled) {
        filled++;
      }
    }
    return filled / bitmap.length;
  }

  List<List<int>> _cluesForRows(List<int> cells, int width, int height) {
    final List<List<int>> clues = <List<int>>[];
    for (int row = 0; row < height; row++) {
      final List<int> values = <int>[];
      int run = 0;
      for (int col = 0; col < width; col++) {
        final int value = cells[row * width + col];
        if (value == NonogramLineSolver.filled) {
          run++;
        } else {
          if (run > 0) {
            values.add(run);
            run = 0;
          }
        }
      }
      if (run > 0) {
        values.add(run);
      }
      clues.add(values);
    }
    return clues;
  }

  List<List<int>> _cluesForColumns(List<int> cells, int width, int height) {
    final List<List<int>> clues = <List<int>>[];
    for (int col = 0; col < width; col++) {
      final List<int> values = <int>[];
      int run = 0;
      for (int row = 0; row < height; row++) {
        final int value = cells[row * width + col];
        if (value == NonogramLineSolver.filled) {
          run++;
        } else {
          if (run > 0) {
            values.add(run);
            run = 0;
          }
        }
      }
      if (run > 0) {
        values.add(run);
      }
      clues.add(values);
    }
    return clues;
  }
}
