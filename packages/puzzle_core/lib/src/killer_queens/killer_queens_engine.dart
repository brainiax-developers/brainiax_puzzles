import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
import '../validation/validator.dart';
import 'killer_queens_board.dart';
import 'killer_queens_difficulty.dart';
import 'killer_queens_generator.dart';
import 'killer_queens_move.dart';
import 'killer_queens_solver.dart';
import 'killer_queens_validator.dart';

DifficultyBucketConfig _loadKillerQueensDifficultyConfig() {
  return const DifficultyConfigLoader().loadSync(
    'assets/killer_queens_difficulty_thresholds.json',
  );
}

class KillerQueensEngine
    extends PipelinePuzzleEngine<KillerQueensBoard, KillerQueensMove> {
  KillerQueensEngine({DifficultyBucketConfig? config})
    : super(
        engineId: 'killer_queens',
        engineName: 'Killer Queens',
        engineVersion: '1.0.0',
        generator: const KillerQueensGenerator(),
        solver: const KillerQueensSolver(),
        validator: const KillerQueensValidator(),
        difficultyScorer: const KillerQueensDifficultyScorer(),
        difficultyConfig: config ?? _loadKillerQueensDifficultyConfig(),
        enforceDifficulty: false,
      );

  @override
  MoveResult<KillerQueensBoard> validateMove({
    required KillerQueensBoard currentState,
    required KillerQueensMove move,
  }) {
    if (move.row < 0 || move.row >= currentState.size) {
      return MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= currentState.size) {
      return MoveResult.failure('col_out_of_range');
    }
    if (move.value != 0 && move.value != 1 && move.value != 2) {
      return MoveResult.failure('value_out_of_range');
    }

    final int index = currentState.indexFor(move.row, move.col);
    if (currentState.fixed[index]) {
      return MoveResult.failure('cell_is_fixed');
    }

    final List<int> updatedCells = List<int>.from(currentState.cells);
    final List<bool> updatedFixed = List<bool>.from(currentState.fixed);
    updatedCells[index] = move.value;
    final KillerQueensBoard updated = KillerQueensBoard(
      size: currentState.size,
      cells: updatedCells,
      fixed: updatedFixed,
      cages: currentState.cages,
    );

    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }
}
