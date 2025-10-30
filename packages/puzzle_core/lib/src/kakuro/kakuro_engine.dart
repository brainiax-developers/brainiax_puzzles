import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../util/determinism.dart';
import '../validation/validator.dart';
import 'kakuro_board.dart';
import 'kakuro_difficulty.dart';
import 'kakuro_generator.dart';
import 'kakuro_move.dart';
import 'kakuro_solver.dart';
import 'kakuro_validator.dart';

DifficultyBucketConfig _loadKakuroDifficultyConfig() {
  return const DifficultyConfigLoader()
      .loadSync('assets/kakuro_difficulty_thresholds.json');
}

class KakuroEngine extends PipelinePuzzleEngine<KakuroBoard, KakuroMove> {
  KakuroEngine({DifficultyBucketConfig? config})
      : super(
          engineId: 'kakuro_classic',
          engineName: 'Classic Kakuro',
          engineVersion: '1.2.0',
          generator: const KakuroGenerator(),
          solver: const KakuroSolver(),
          validator: const KakuroValidator(),
          difficultyScorer: const KakuroDifficultyScorer(),
          difficultyConfig: config ?? _loadKakuroDifficultyConfig(),
          enforceDifficulty: false, // Disable strict difficulty enforcement for Kakuro
        );

  @override
  MoveResult<KakuroBoard> validateMove({
    required KakuroBoard currentState,
    required KakuroMove move,
  }) {
    if (move.row < 0 || move.row >= currentState.height) {
      return MoveResult.failure('row_out_of_range');
    }
    if (move.col < 0 || move.col >= currentState.width) {
      return MoveResult.failure('col_out_of_range');
    }
    if (move.digit < 0 || move.digit > 9) {
      return MoveResult.failure('digit_out_of_range');
    }

    final int index = currentState.indexOf(move.row, move.col);
    if (!currentState.isPlayableIndex(index)) {
      return MoveResult.failure('cell_not_playable');
    }

    final KakuroBoard updated = currentState.setValue(index, move.digit);
    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(updated.toJson());

    return MoveResult.success(updated);
  }
}
