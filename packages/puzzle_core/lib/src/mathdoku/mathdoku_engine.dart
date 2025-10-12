import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
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
}
