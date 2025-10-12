import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
import '../validation/validator.dart';
import 'futoshiki_board.dart';
import 'futoshiki_difficulty.dart';
import 'futoshiki_generator.dart';
import 'futoshiki_move.dart';
import 'futoshiki_solver.dart';
import 'futoshiki_validator.dart';

DifficultyBucketConfig _loadFutoshikiDifficultyConfig() {
  return const DifficultyConfigLoader()
      .loadSync('assets/futoshiki_difficulty_thresholds.json');
}

class FutoshikiEngine
    extends PipelinePuzzleEngine<FutoshikiBoard, FutoshikiMove> {
  FutoshikiEngine({DifficultyBucketConfig? config})
      : super(
          engineId: 'futoshiki_classic',
          engineName: 'Classic Futoshiki',
          engineVersion: '1.0.0',
          generator: const FutoshikiGenerator(),
          solver: const FutoshikiSolver(),
          validator: const FutoshikiValidator(),
          difficultyScorer: const FutoshikiDifficultyScorer(),
          difficultyConfig: config ?? _loadFutoshikiDifficultyConfig(),
        );

  @override
  MoveResult<FutoshikiBoard> validateMove({
    required FutoshikiBoard currentState,
    required FutoshikiMove move,
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

    final int index = move.row * currentState.size + move.col;
    if (currentState.fixed[index]) {
      return MoveResult.failure('cell_is_fixed');
    }

    final List<int> newCells = List<int>.from(currentState.cells);
    final List<bool> newFixed = List<bool>.from(currentState.fixed);
    newCells[index] = move.value;
    final FutoshikiBoard updated = FutoshikiBoard(
      size: currentState.size,
      cells: newCells,
      fixed: newFixed,
      inequalities: currentState.inequalities,
    );

    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }
}
