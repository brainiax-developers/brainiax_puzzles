import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
import '../validation/validator.dart';
import 'takuzu_board.dart';
import 'takuzu_difficulty.dart';
import 'takuzu_generator.dart';
import 'takuzu_move.dart';
import 'takuzu_solver.dart';
import 'takuzu_validator.dart';

DifficultyBucketConfig _loadTakuzuDifficultyConfig() {
  return const DifficultyConfigLoader()
      .loadSync('assets/takuzu_difficulty_thresholds.json');
}

class TakuzuEngine extends PipelinePuzzleEngine<TakuzuBoard, TakuzuMove> {
  TakuzuEngine({DifficultyBucketConfig? config})
      : super(
          engineId: 'takuzu_binary',
          engineName: 'Takuzu',
          engineVersion: '1.0.0',
          generator: const TakuzuGenerator(),
          solver: const TakuzuSolver(),
          validator: const TakuzuValidator(),
          difficultyScorer: const TakuzuDifficultyScorer(),
          difficultyConfig: config ?? _loadTakuzuDifficultyConfig(),
        );

  @override
  MoveResult<TakuzuBoard> validateMove({
    required TakuzuBoard currentState,
    required TakuzuMove move,
  }) {
    if (move.row < 0 || move.row >= currentState.size) {
      return MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= currentState.size) {
      return MoveResult.failure('col_out_of_range');
    }
    if (move.value != TakuzuBoard.empty && move.value != 0 && move.value != 1) {
      return MoveResult.failure('value_out_of_range');
    }

    final int index = currentState.cellIndex(move.row, move.col);
    if (currentState.fixed[index]) {
      return MoveResult.failure('cell_is_fixed');
    }

    final List<int> updatedCells = List<int>.from(currentState.cells);
    updatedCells[index] = move.value;
    final TakuzuBoard updated = TakuzuBoard(
      size: currentState.size,
      cells: updatedCells,
      fixed: currentState.fixed,
    );

    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }
}
