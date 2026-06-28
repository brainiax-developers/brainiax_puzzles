import 'package:puzzle_core/puzzle_core.dart';
import 'kakuro_board.dart';
import 'kakuro_move.dart';
import 'kakuro_generator.dart';
import 'kakuro_solver.dart';
import 'kakuro_validator.dart';

class KakuroDifficultyScorer implements DifficultyScorer<KakuroBoard> {
  const KakuroDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required KakuroBoard puzzle,
    required KakuroBoard solution,
    required DifficultyContext context,
  }) {
    // Simple mock scoring based on telemetry from generator
    final nodes = (context.generatorTelemetry['solver_nodes'] as int?) ?? 1;
    final backtracks = (context.generatorTelemetry['solver_backtracks'] as int?) ?? 1;

    double score = (nodes * 1.0) + (backtracks * 2.0);
    
    String bucket = 'easy';
    if (score > 100000) bucket = 'expert';
    else if (score > 10000) bucket = 'hard';
    else if (score > 1000) bucket = 'medium';

    return DifficultyTelemetry(
      rawScore: score,
      bucket: bucket,
    );
  }
}

class KakuroEngine extends PipelinePuzzleEngine<KakuroBoard, KakuroMove> {
  KakuroEngine()
      : super(
          engineId: 'kakuro',
          engineName: 'Kakuro',
          engineVersion: '1.0.0',
          generator: const KakuroGenerator(),
          solver: const KakuroSolver(),
          validator: const KakuroValidator(),
          difficultyScorer: const KakuroDifficultyScorer(),
          difficultyConfig: const DifficultyBucketConfig(
            buckets: [
              DifficultyBucketThreshold(id: 'easy', maxInclusive: 1000),
              DifficultyBucketThreshold(id: 'medium', maxInclusive: 10000),
              DifficultyBucketThreshold(id: 'hard', maxInclusive: 100000),
              DifficultyBucketThreshold(id: 'expert', maxInclusive: 9999999),
            ],
          ),
        );

  @override
  PuzzleCapabilities get capabilities => const PuzzleCapabilities(
        supportsHints: false, // Hints omitted for now
      );

  @override
  MoveResult<KakuroBoard> validateMove({
    required KakuroBoard currentState,
    required KakuroMove move,
  }) {
    if (move.index < 0 || move.index >= currentState.cellCount) {
      return MoveResult.failure('index_out_of_range');
    }
    if (move.value < 0 || move.value > 9) {
      return MoveResult.failure('digit_out_of_range');
    }

    if (!currentState.isWhite(move.index)) {
      return MoveResult.failure('cell_is_not_white');
    }

    final KakuroBoard updated = currentState.setCellValue(move.index, move.value);

    // Structural validation check
    final ValidationSummary summary = validator.validatePuzzle(updated);
    if (!summary.isValid) {
      return MoveResult.failure(summary.issues.join(','));
    }

    return MoveResult.success(updated);
  }

  @override
  PuzzleHint? requestHint({
    required KakuroBoard currentState,
    PuzzleHintRequest? request,
  }) {
    return null;
  }
}
