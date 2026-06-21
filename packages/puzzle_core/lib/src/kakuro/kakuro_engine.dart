import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../engine/pipeline_engine.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import '../validation/validator.dart';
import 'kakuro_board.dart';
import 'kakuro_difficulty.dart';
import 'kakuro_generator.dart';
import 'kakuro_move.dart';
import 'kakuro_solver.dart';
import 'kakuro_validator.dart';

DifficultyBucketConfig _loadKakuroDifficultyConfig() {
  return const DifficultyConfigLoader().loadSync(
    'assets/kakuro_difficulty_thresholds.json',
  );
}

class KakuroEngine extends PipelinePuzzleEngine<KakuroBoard, KakuroMove> {
  KakuroEngine({DifficultyBucketConfig? config, KakuroGenerator? generator})
    : super(
        engineId: 'kakuro_classic',
        engineName: 'Classic Kakuro',
        engineVersion: '1.2.0',
        generator: generator ?? const KakuroGenerator(),
        solver: const KakuroSolver(),
        validator: const KakuroValidator(),
        difficultyScorer: const KakuroDifficultyScorer(),
        difficultyConfig: config ?? _loadKakuroDifficultyConfig(),
        enforceDifficulty:
            false, // Disable strict difficulty enforcement for Kakuro
      );

  @override
  PuzzleCapabilities get capabilities =>
      const PuzzleCapabilities(supportsHints: true);

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

  @override
  PuzzleHint? requestHint({
    required KakuroBoard currentState,
    PuzzleHintRequest? request,
  }) {
    // Collect playable, empty cells.
    final List<int> empty = <int>[];
    for (int i = 0; i < currentState.cellCount; i++) {
      if (!currentState.isPlayableIndex(i)) {
        continue;
      }
      if (currentState.values[i] == 0) {
        empty.add(i);
      }
    }
    if (empty.isEmpty) {
      return null;
    }

    // Solve to get a consistent completed board.
    final int seed = request?.seed64 ?? currentState.hashCode;
    final KakuroSolver solver = const KakuroSolver();
    final SolverContext context = SolverContext(
      rng: SeededRng(seed),
      maxSolutions: 1,
    );
    final SolverResult<KakuroBoard> result = solver.solve(
      currentState,
      context,
    );
    if (!result.hasSolution) {
      return null;
    }
    final KakuroBoard solution = result.solutions.first;
    if (solution.values.length != currentState.values.length) {
      return null;
    }

    final int iteration = request?.iteration ?? 0;
    final SeededRng rng = SeededRng(seed ^ 0x9e3779b97f4a7c15 ^ iteration);
    final int chosenIndex = empty[rng.nextIntInRange(empty.length)];
    final int row = chosenIndex ~/ currentState.width;
    final int col = chosenIndex % currentState.width;
    final int digit = solution.values[chosenIndex];
    if (digit <= 0 || digit > 9) {
      return null;
    }

    final PuzzleHintCell cell = PuzzleHintCell(
      row: row,
      column: col,
      metadata: <String, Object?>{'digit': digit},
    );

    return PuzzleHint(
      cells: <PuzzleHintCell>[cell],
      metadata: <String, Object?>{
        'engineId': engineId,
        'kind': 'fill_single_cell',
      },
    );
  }
}
