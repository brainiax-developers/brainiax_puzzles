import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/nonogram.dart';
import '../util/seeded_rng.dart';
import '../validation/validator.dart';
import 'nonogram_board.dart';
import 'nonogram_difficulty.dart';
import 'nonogram_generator.dart';
import 'nonogram_move.dart';
import 'nonogram_solver.dart';
import 'nonogram_validator.dart';

DifficultyBucketConfig _loadNonogramDifficultyConfig() {
  return const DifficultyConfigLoader()
      .loadSync('assets/nonogram_difficulty_thresholds.json');
}

class NonogramEngine extends PipelinePuzzleEngine<NonogramBoard, NonogramMove> {
  NonogramEngine({DifficultyBucketConfig? config})
      : super(
          engineId: 'nonogram_mono',
          engineName: 'Monochrome Nonogram',
          engineVersion: '1.0.0',
          generator: const NonogramGenerator(),
          solver: const NonogramSolver(),
          validator: const NonogramValidator(),
          difficultyScorer: const NonogramDifficultyScorer(),
          difficultyConfig: config ?? _loadNonogramDifficultyConfig(),
        );

  @override
  PuzzleCapabilities get capabilities => const PuzzleCapabilities(
        supportsHints: true,
      );

  @override
  MoveResult<NonogramBoard> validateMove({
    required NonogramBoard currentState,
    required NonogramMove move,
  }) {
    if (move.row < 0 || move.row >= currentState.height) {
      return MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= currentState.width) {
      return MoveResult.failure('col_out_of_range');
    }
    if (move.value != null &&
        move.value != NonogramLineSolver.filled &&
        move.value != NonogramLineSolver.empty) {
      return MoveResult.failure('value_out_of_range');
    }

    final int index = currentState.indexOf(move.row, move.col);
    final List<int?> newCells = List<int?>.from(currentState.cells);
    newCells[index] = move.value;
    final NonogramBoard updated = currentState.copyWith(cells: newCells);

    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }

  @override
  PuzzleHint? requestHint({
    required NonogramBoard currentState,
    PuzzleHintRequest? request,
  }) {
    if (currentState.isComplete) {
      return null;
    }

    final NonogramSolver logicSolver = const NonogramSolver();
    final SolverContext context = SolverContext(
      rng: SeededRng(request?.seed64 ?? currentState.hashCode),
      maxSolutions: 1,
    );
    final SolverResult<NonogramBoard> result =
        logicSolver.solve(currentState, context);
    if (!result.hasSolution) {
      return null;
    }

    final NonogramBoard solution = result.solutions.first;
    if (solution.cellCount != currentState.cellCount) {
      return null;
    }

    final List<int> candidateIndices = <int>[];
    for (int i = 0; i < currentState.cellCount; i++) {
      final int? current = currentState.cells[i];
      if (current != null) {
        continue;
      }
      final int? solved = solution.cells[i];
      if (solved == null) {
        continue;
      }
      if (solved != NonogramLineSolver.filled &&
          solved != NonogramLineSolver.empty) {
        continue;
      }
      candidateIndices.add(i);
    }

    if (candidateIndices.isEmpty) {
      return null;
    }

    final int iteration = request?.iteration ?? 0;
    final int chosenIndex =
        candidateIndices[iteration % candidateIndices.length];
    final int row = chosenIndex ~/ currentState.width;
    final int col = chosenIndex % currentState.width;
    final int value = solution.cells[chosenIndex]!;

    final PuzzleHintCell cell = PuzzleHintCell(
      row: row,
      column: col,
      metadata: <String, Object?>{
        'value': value,
      },
    );

    final String kind = value == NonogramLineSolver.filled
        ? 'fill_single_cell'
        : 'mark_empty_cell';

    return PuzzleHint(
      cells: <PuzzleHintCell>[cell],
      metadata: <String, Object?>{
        'engineId': engineId,
        'kind': kind,
      },
    );
  }
}
