import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../validation/validator.dart';
import '../util/seeded_rng.dart';
import 'takuzu_board.dart';
import 'takuzu_solver.dart';
import 'takuzu_validator.dart';

class TakuzuGenerator extends PuzzleGenerator<TakuzuBoard> {
  const TakuzuGenerator();

  // Supported square sizes. Expert may use 12x12 or larger.
  static const List<int> _supportedSizes = <int>[4, 6, 8, 10, 12];

  // Difficulty targets derived from product requirements.
  // Ratios are expressed as fraction of cells kept as givens.
  static const Map<String, _DifficultyProfile> _profiles = <String, _DifficultyProfile>{
    'easy': _DifficultyProfile(minGivenRatio: 0.50, maxGivenRatio: 0.60, minChain: 0, maxChain: 1),
    'medium': _DifficultyProfile(minGivenRatio: 0.40, maxGivenRatio: 0.50, minChain: 1, maxChain: 2),
    'hard': _DifficultyProfile(minGivenRatio: 0.30, maxGivenRatio: 0.40, minChain: 3, maxChain: 5),
    // Expert focuses on deep reasoning; allow sparse givens and high chains.
    'expert': _DifficultyProfile(minGivenRatio: 0.20, maxGivenRatio: 0.30, minChain: 6, maxChain: 9999),
  };

  @override
  PuzzleGenerationResult<TakuzuBoard> generate(GeneratorContext context) {
    final int width = context.size.width;
    final int height = context.size.height;
    if (width != height) {
      throw ArgumentError('Takuzu requires square grids; got ${width}x$height');
    }
    if (width.isOdd) {
      throw ArgumentError('Takuzu requires even dimension; got $width');
    }
    if (!_supportedSizes.contains(width)) {
      throw ArgumentError('Unsupported Takuzu size: ${width}x$height');
    }

    final Stopwatch stopwatch = Stopwatch()..start();

    final List<int> solutionCells = _buildSolution(width, context.rng);
    final List<int> puzzleCells = List<int>.from(solutionCells);
    final List<bool> fixed = List<bool>.filled(width * width, true, growable: false);

    final TakuzuSolver solver = const TakuzuSolver();
    final TakuzuValidator validator = const TakuzuValidator();
    final int solverSeedBase = context.rng.nextInt64();
    int solverInvocation = 0;

    (_SolveCheckResult, ValidationSummary) solveCheck() {
      final TakuzuBoard puzzle = TakuzuBoard(size: width, cells: puzzleCells, fixed: fixed);
      final SolverContext solverContext = SolverContext(
        rng: SeededRng(solverSeedBase ^ solverInvocation++),
        maxSolutions: 2,
      );
      final SolverResult<TakuzuBoard> result = solver.solve(puzzle, solverContext);
      final bool ok = result.hasSolution && result.isUnique;
      if (!ok) {
        return (_SolveCheckResult(unique: false, longestChain: 0), validator.validatePuzzle(puzzle));
      }
      final ValidationSummary vs = validator.validateSolution(puzzle, result.solutions.first);
      final int longestChain = (result.telemetry['longestChain'] as int?) ??
          ((result.telemetry['longestChain'] as num?)?.toInt() ?? 0);
      return (_SolveCheckResult(unique: ok && vs.isValid, longestChain: longestChain), vs);
    }

    final (_SolveCheckResult initialCheck, ValidationSummary initialVs) = solveCheck();
    if (!(initialCheck.unique && initialVs.isValid)) {
      throw StateError('Failed to produce solvable Takuzu board');
    }

  List<int> removalOrder =
        context.rng.permute(List<int>.generate(width * width, (int i) => i));

    // Difficulty targeting
    final String level = context.difficulty.level.toLowerCase();
    final _DifficultyProfile profile = _profiles[level] ?? _profiles['medium']!;

  int removed = 0;
  int acceptedLongestChain = initialCheck.longestChain;
  // Attempts counter removed; kept simple single-pass peel strategy.
    final int totalCells = width * width;
    final int minGivens = (totalCells * profile.minGivenRatio).ceil();
    final int maxGivens = (totalCells * profile.maxGivenRatio).ceil();

    bool ratioWithinBand(int givens) {
      if (level == 'expert') {
        // Expert accepts any ratio <= max.
        return givens <= maxGivens;
      }
      return givens >= minGivens && givens <= maxGivens;
    }

    int currentGivens0() => puzzleCells.where((int v) => v != TakuzuBoard.emptyValue).length;

    // Try to peel cells while ensuring uniqueness and matching difficulty targets.
    int passes = 0;
    bool changed = true;
    while (changed && passes < 4) {
      changed = false;
      passes++;
      for (final int index in removalOrder) {
        final int currentGivens = currentGivens0();
        // Stop early if we are already in the desired ratio band and (for non-easy)
        // we achieved minimum chain depth.
        if (ratioWithinBand(currentGivens) &&
            (level == 'easy' || acceptedLongestChain >= profile.minChain)) {
          break;
        }

        final int previous = puzzleCells[index];
        if (previous == TakuzuBoard.emptyValue) {
          continue;
        }

        puzzleCells[index] = TakuzuBoard.emptyValue;
        fixed[index] = false;

        // Do not allow dropping below min givens for non-expert levels.
        final int afterGivens = currentGivens0();
        if (level != 'expert' && afterGivens < minGivens) {
          puzzleCells[index] = previous;
          fixed[index] = true;
          continue;
        }

        final (_SolveCheckResult check, ValidationSummary vs) = solveCheck();
        if (!(check.unique && vs.isValid)) {
          // Revert removal – uniqueness or validity broke.
          puzzleCells[index] = previous;
          fixed[index] = true;
          continue;
        }

        // Accept this removal unconditionally for Easy; for others, it
        // naturally increases difficulty and helps reach minChain.
        removed++;
        acceptedLongestChain = check.longestChain;
        changed = true;
      }
      // Shuffle order for the next pass to explore other candidates.
      if (!(ratioWithinBand(currentGivens0()) &&
          (level == 'easy' || acceptedLongestChain >= profile.minChain))) {
        removalOrder = context.rng.permute(removalOrder);
      }
    }

    final TakuzuBoard puzzle = TakuzuBoard(size: width, cells: puzzleCells, fixed: fixed);

    stopwatch.stop();

    final Map<String, Object?> telemetry = <String, Object?>{
      'size': width,
      'givens': puzzle.cells.where((int value) => value != TakuzuBoard.emptyValue).length,
      'removed': removed,
      'generationUs': stopwatch.elapsedMicroseconds,
      'difficultyRequest': level,
      'minGivenRatio': profile.minGivenRatio,
      'maxGivenRatio': profile.maxGivenRatio,
      'targetMinChain': profile.minChain,
      'targetMaxChain': profile.maxChain,
      'longestChain': acceptedLongestChain,
    };

    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle.toJson());

    return PuzzleGenerationResult<TakuzuBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  List<int> _buildSolution(int size, SeededRng rng) {
    final List<List<int>> patterns = _generateValidRows(size);
    final List<List<int>> rows = List<List<int>>.generate(
      size,
      (_) => List<int>.filled(size, TakuzuBoard.emptyValue),
      growable: false,
    );
    final List<List<int>> columnAssignments =
        List<List<int>>.generate(size, (_) => <int>[], growable: false);
    final List<int> columnZeros = List<int>.filled(size, 0, growable: false);
    final List<int> columnOnes = List<int>.filled(size, 0, growable: false);
    final Set<String> usedRows = <String>{};

    bool placeRow(int rowIndex) {
      if (rowIndex == size) {
        return _validateColumns(columnAssignments, size);
      }

      final List<int> order =
          rng.permute(List<int>.generate(patterns.length, (int i) => i));
      for (final int patternIndex in order) {
        final List<int> pattern = patterns[patternIndex];
        final String key = pattern.join();
        if (usedRows.contains(key)) {
          continue;
        }
        if (!_canPlaceRow(
          rowIndex,
          pattern,
          columnAssignments,
          columnZeros,
          columnOnes,
          size,
        )) {
          continue;
        }
        usedRows.add(key);
        _applyRow(
          rows,
          rowIndex,
          pattern,
          columnAssignments,
          columnZeros,
          columnOnes,
        );
        if (placeRow(rowIndex + 1)) {
          return true;
        }
        usedRows.remove(key);
        _removeRow(
          rows,
          rowIndex,
          pattern,
          columnAssignments,
          columnZeros,
          columnOnes,
        );
      }
      return false;
    }

    final bool success = placeRow(0);
    if (!success) {
      throw StateError('Unable to construct Takuzu solution for size $size');
    }

    final List<int> flattened = <int>[];
    for (final List<int> row in rows) {
      flattened.addAll(row);
    }
    return flattened;
  }

  List<List<int>> _generateValidRows(int size) {
    final int limit = size ~/ 2;
    final List<List<int>> patterns = <List<int>>[];

    void backtrack(List<int> current, int zeros, int ones) {
      if (current.length == size) {
        if (zeros == limit && ones == limit) {
          patterns.add(List<int>.from(current));
        }
        return;
      }
      if (zeros < limit && !_wouldFormTriple(current, 0)) {
        current.add(0);
        backtrack(current, zeros + 1, ones);
        current.removeLast();
      }
      if (ones < limit && !_wouldFormTriple(current, 1)) {
        current.add(1);
        backtrack(current, zeros, ones + 1);
        current.removeLast();
      }
    }

    backtrack(<int>[], 0, 0);
    return patterns;
  }

  bool _wouldFormTriple(List<int> current, int candidate) {
    final int len = current.length;
    if (len < 2) {
      return false;
    }
    return current[len - 1] == candidate && current[len - 2] == candidate;
  }

  bool _canPlaceRow(
    int rowIndex,
    List<int> pattern,
    List<List<int>> columnAssignments,
    List<int> columnZeros,
    List<int> columnOnes,
    int size,
  ) {
    final int limit = size ~/ 2;
    for (int col = 0; col < size; col++) {
      final int value = pattern[col];
      if (value == 0) {
        if (columnZeros[col] + 1 > limit) {
          return false;
        }
      } else {
        if (columnOnes[col] + 1 > limit) {
          return false;
        }
      }
      final List<int> assignments = columnAssignments[col];
      if (assignments.length >= 2 &&
          assignments[assignments.length - 1] == value &&
          assignments[assignments.length - 2] == value) {
        return false;
      }
    }
    return true;
  }

  void _applyRow(
    List<List<int>> rows,
    int rowIndex,
    List<int> pattern,
    List<List<int>> columnAssignments,
    List<int> columnZeros,
    List<int> columnOnes,
  ) {
    for (int col = 0; col < pattern.length; col++) {
      final int value = pattern[col];
      rows[rowIndex][col] = value;
      columnAssignments[col].add(value);
      if (value == 0) {
        columnZeros[col]++;
      } else {
        columnOnes[col]++;
      }
    }
  }

  void _removeRow(
    List<List<int>> rows,
    int rowIndex,
    List<int> pattern,
    List<List<int>> columnAssignments,
    List<int> columnZeros,
    List<int> columnOnes,
  ) {
    for (int col = 0; col < pattern.length; col++) {
      final int value = pattern[col];
      rows[rowIndex][col] = TakuzuBoard.emptyValue;
      columnAssignments[col].removeLast();
      if (value == 0) {
        columnZeros[col]--;
      } else {
        columnOnes[col]--;
      }
    }
  }

  bool _validateColumns(List<List<int>> columnAssignments, int size) {
    final int limit = size ~/ 2;
    final Set<String> seen = <String>{};
    for (int col = 0; col < size; col++) {
      final List<int> values = columnAssignments[col];
      if (values.length != size) {
        return false;
      }
      int zeros = 0;
      int ones = 0;
      final StringBuffer buffer = StringBuffer();
      for (final int value in values) {
        buffer.write(value);
        if (value == 0) {
          zeros++;
        } else {
          ones++;
        }
      }
      if (zeros != limit || ones != limit) {
        return false;
      }
      final String signature = buffer.toString();
      if (!seen.add(signature)) {
        return false;
      }
    }
    return true;
  }
}

class _SolveCheckResult {
  const _SolveCheckResult({required this.unique, required this.longestChain});
  final bool unique;
  final int longestChain;
}

class _DifficultyProfile {
  const _DifficultyProfile({
    required this.minGivenRatio,
    required this.maxGivenRatio,
    required this.minChain,
    required this.maxChain,
  });
  final double minGivenRatio;
  final double maxGivenRatio;
  final int minChain;
  final int maxChain;
}
