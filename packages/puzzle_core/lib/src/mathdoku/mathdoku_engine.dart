import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import '../validation/validator.dart';
import 'mathdoku_board.dart';
import 'mathdoku_difficulty.dart';
import 'mathdoku_generator.dart';
import 'mathdoku_move.dart';
import 'mathdoku_solver.dart';
import 'mathdoku_validator.dart';

DifficultyBucketConfig _loadMathdokuDifficultyConfig() {
  return const DifficultyConfigLoader().loadSync('assets/mathdoku_difficulty_thresholds.json');
}

class MathdokuEngine extends PipelinePuzzleEngine<MathdokuBoard, MathdokuMove> {
  MathdokuEngine({DifficultyBucketConfig? config})
      : super(
          engineId: 'mathdoku_classic',
          engineName: 'Mathdoku',
          engineVersion: '1.0.0',
          generator: const MathdokuGenerator(),
          solver: const MathdokuSolver(),
          validator: const MathdokuValidator(),
          difficultyScorer: const MathdokuDifficultyScorer(),
          difficultyConfig: config ?? _loadMathdokuDifficultyConfig(),
        );

  @override
  PuzzleCapabilities get capabilities => const PuzzleCapabilities(
        supportsHints: true,
      );

  @override
  MoveResult<MathdokuBoard> validateMove({
    required MathdokuBoard currentState,
    required MathdokuMove move,
  }) {
    if (move.row < 0 || move.row >= currentState.size) {
      return MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= currentState.size) {
      return MoveResult.failure('col_out_of_range');
    }
    if (move.value < 0 || move.value > currentState.size) {
      return MoveResult.failure('value_out_of_range');
    }

    final MathdokuBoard updated = currentState.setCell(move.row, move.col, move.value);
    final ValidationSummary validation = validator.validatePuzzle(updated);
    if (!validation.isValid) {
      return MoveResult.failure(validation.issues.join(','));
    }
    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());
    return MoveResult.success(updated);
  }

  @override
  PuzzleHint? requestHint({
    required MathdokuBoard currentState,
    PuzzleHintRequest? request,
  }) {
    final List<int> emptyIndices = <int>[];
    for (int i = 0; i < currentState.cellCount; i++) {
      if (currentState.cells[i] == 0) {
        emptyIndices.add(i);
      }
    }

    if (emptyIndices.isEmpty) {
      return PuzzleHint(
        metadata: <String, Object?>{
          'engineId': engineId,
          'kind': 'no_available_cells',
          'message': 'All cells are already filled',
        },
      );
    }

    final MathdokuSolver logicSolver = const MathdokuSolver();
    final int seed = request?.seed64 ?? (currentState.hashCode ^ (request?.iteration ?? 0));
    final SolverContext solverContext = SolverContext(
      rng: SeededRng(seed),
      maxSolutions: 1,
    );
    final SolverResult<MathdokuBoard> result =
        logicSolver.solve(currentState, solverContext);
    if (!result.hasSolution) {
      return PuzzleHint(
        metadata: <String, Object?>{
          'engineId': engineId,
          'kind': 'no_solution_available',
        },
      );
    }

    final MathdokuBoard solution = result.solutions.first;
    if (solution.cells.length != currentState.cells.length) {
      return PuzzleHint(
        metadata: <String, Object?>{
          'engineId': engineId,
          'kind': 'no_solution_available',
        },
      );
    }

    final List<int> candidateIndices = <int>[];
    for (final int index in emptyIndices) {
      final int value = solution.cells[index];
      if (value > 0 && value <= currentState.size) {
        candidateIndices.add(index);
      }
    }
    if (candidateIndices.isEmpty) {
      return PuzzleHint(
        metadata: <String, Object?>{
          'engineId': engineId,
          'kind': 'no_available_cells',
          'message': 'No empty cells with a deterministic value found',
        },
      );
    }

    final SeededRng rng = SeededRng(seed ^ 0x9e3779b97f4a7c15);
    final int chosenIndex = candidateIndices[rng.nextIntInRange(candidateIndices.length)];
    final int row = chosenIndex ~/ currentState.size;
    final int col = chosenIndex % currentState.size;
    final int value = solution.cells[chosenIndex];

    final PuzzleHintCell cell = PuzzleHintCell(
      row: row,
      column: col,
      metadata: <String, Object?>{
        'value': value,
      },
    );

    return PuzzleHint(
      cells: <PuzzleHintCell>[cell],
      metadata: <String, Object?>{
        'engineId': engineId,
        'kind': 'reveal_single_cell',
      },
    );
  }
}
