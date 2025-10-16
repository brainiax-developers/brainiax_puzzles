import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
import '../util/nonogram.dart';
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
}
