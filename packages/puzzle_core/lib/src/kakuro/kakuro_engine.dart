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
    final nodes = (context.generatorTelemetry['solver_nodes'] as int?) ?? 1;
    final backtracks = (context.generatorTelemetry['solver_backtracks'] as int?) ?? 1;

    int whiteCount = 0;
    for (int i = 0; i < puzzle.cellCount; i++) {
      if (puzzle.isWhite(i)) whiteCount++;
    }

    // Combine solver computational difficulty with board size (white cells).
    // Larger boards are cognitively harder for humans regardless of solver efficiency.
    double score = (nodes * 1.0) + (backtracks * 5.0) + (whiteCount * 40.0);
    
    String bucket = 'easy';
    if (score > 2100) bucket = 'expert';
    else if (score > 1550) bucket = 'hard';
    else if (score > 1100) bucket = 'medium';

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
              DifficultyBucketThreshold(id: 'easy', maxInclusive: 1100),
              DifficultyBucketThreshold(id: 'medium', maxInclusive: 1550),
              DifficultyBucketThreshold(id: 'hard', maxInclusive: 2100),
              DifficultyBucketThreshold(id: 'expert', maxInclusive: 9999999),
            ],
          ),
        );

  @override
  PuzzleCapabilities get capabilities => const PuzzleCapabilities(
        supportsHints: true,
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
    final SolverContext context = SolverContext(
      rng: SeededRng(Seed.fromString('hint')),
      maxSolutions: 1,
    );
    final result = solver.solve(currentState, context);
    if (result.solutions.isEmpty) return null;
    
    final KakuroBoard solution = result.solutions.first;
    for (int i = 0; i < currentState.cellTypes.length; i++) {
      if (currentState.cellTypes[i] == KakuroBoard.cellWhite) {
        if (currentState.cellValues[i] == 0) {
          return PuzzleHint(cells: [
            PuzzleHintCell(
              row: i ~/ currentState.width,
              column: i % currentState.width,
              metadata: {'digit': solution.cellValues[i]},
            )
          ]);
        }
      }
    }
    return null;
  }
}
