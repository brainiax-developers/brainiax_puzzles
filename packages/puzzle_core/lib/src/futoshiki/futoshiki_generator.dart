import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import 'futoshiki_board.dart';
import 'futoshiki_solver.dart';

class FutoshikiGenerator extends PuzzleGenerator<FutoshikiBoard> {
  const FutoshikiGenerator();

  static const List<int> _supportedSizes = <int>[4, 5];

  @override
  PuzzleGenerationResult<FutoshikiBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (width != height) {
      throw ArgumentError('Futoshiki requires square grids; got ${width}x$height');
    }
    if (!_supportedSizes.contains(width)) {
      throw ArgumentError('Unsupported Futoshiki size: ${width}x$height');
    }

    final Stopwatch stopwatch = Stopwatch()..start();

    final List<int> solution = _buildLatinSolution(context.rng, width);
    final List<FutoshikiInequality> allInequalities =
        _buildInequalities(width, solution);

    final List<FutoshikiInequality> active =
        List<FutoshikiInequality>.from(allInequalities);

    final int solverSeed = context.rng.nextInt64();
    int solverInvocation = 0;
    final FutoshikiSolver solver = const FutoshikiSolver();

    bool _isUnique(List<FutoshikiInequality> inequalities) {
      final FutoshikiBoard puzzle =
          FutoshikiBoard.empty(size: width, inequalities: inequalities);
      final SolverContext solverContext = SolverContext(
        rng: SeededRng(solverSeed ^ solverInvocation++),
        maxSolutions: 2,
      );
      final SolverResult<FutoshikiBoard> result = solver.solve(puzzle, solverContext);
      return result.hasSolution && result.isUnique;
    }

    if (!_isUnique(active)) {
      throw StateError('Failed to produce solvable Futoshiki board');
    }

    final List<int> removalOrder =
        context.rng.permute(List<int>.generate(active.length, (int i) => i));

    final Set<int> retained = <int>{for (int i = 0; i < active.length; i++) i};
    for (final int index in removalOrder) {
      if (!retained.contains(index)) {
        continue;
      }
      final List<FutoshikiInequality> candidate = <FutoshikiInequality>[];
      final List<int> retainedIndices = retained.toList()..sort();
      for (final int i in retainedIndices) {
        if (i == index) {
          continue;
        }
        candidate.add(active[i]);
      }
      candidate.sort((a, b) {
        if (a.lesser != b.lesser) {
          return a.lesser.compareTo(b.lesser);
        }
        return a.greater.compareTo(b.greater);
      });
      if (_isUnique(candidate)) {
        retained.remove(index);
      }
    }

    final List<int> retainedOrder = retained.toList()..sort();
    final List<FutoshikiInequality> puzzleInequalities =
        <FutoshikiInequality>[...retainedOrder.map((int i) => active[i])];
    puzzleInequalities.sort((a, b) {
      if (a.lesser != b.lesser) {
        return a.lesser.compareTo(b.lesser);
      }
      return a.greater.compareTo(b.greater);
    });

    final FutoshikiBoard puzzle =
        FutoshikiBoard.empty(size: width, inequalities: puzzleInequalities);

    stopwatch.stop();

    final Map<String, Object?> telemetry = <String, Object?>{
      'size': width,
      'totalInequalities': allInequalities.length,
      'puzzleInequalities': puzzleInequalities.length,
      'removedInequalities': allInequalities.length - puzzleInequalities.length,
      'generationUs': stopwatch.elapsedMicroseconds,
    };

    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle.toJson());

    return PuzzleGenerationResult<FutoshikiBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  List<int> _buildLatinSolution(SeededRng rng, int size) {
    final List<List<int>> base = List<List<int>>.generate(
      size,
      (int row) => List<int>.generate(size, (int col) => ((row + col) % size) + 1),
      growable: false,
    );

    final List<int> digitMap = List<int>.generate(size, (int index) => index + 1);
    rng.shuffle(digitMap);

    final List<int> rowOrder =
        rng.permute(List<int>.generate(size, (int i) => i));
    final List<int> colOrder =
        rng.permute(List<int>.generate(size, (int i) => i));

    final List<int> cells = List<int>.filled(size * size, 0);
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final int value = base[rowOrder[r]][colOrder[c]];
        cells[r * size + c] = digitMap[value - 1];
      }
    }
    return cells;
  }

  List<FutoshikiInequality> _buildInequalities(int size, List<int> solution) {
    final List<FutoshikiInequality> inequalities = <FutoshikiInequality>[];
    for (int row = 0; row < size; row++) {
      for (int col = 0; col < size; col++) {
        final int index = row * size + col;
        if (col < size - 1) {
          final int rightIndex = index + 1;
          final int leftValue = solution[index];
          final int rightValue = solution[rightIndex];
          if (leftValue < rightValue) {
            inequalities.add(
              FutoshikiInequality(lesser: index, greater: rightIndex),
            );
          } else {
            inequalities.add(
              FutoshikiInequality(lesser: rightIndex, greater: index),
            );
          }
        }
        if (row < size - 1) {
          final int downIndex = index + size;
          final int topValue = solution[index];
          final int bottomValue = solution[downIndex];
          if (topValue < bottomValue) {
            inequalities.add(
              FutoshikiInequality(lesser: index, greater: downIndex),
            );
          } else {
            inequalities.add(
              FutoshikiInequality(lesser: downIndex, greater: index),
            );
          }
        }
      }
    }
    return inequalities;
  }
}
