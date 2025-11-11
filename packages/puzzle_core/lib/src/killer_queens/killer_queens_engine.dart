import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../engine/pipeline_engine.dart';
import '../generators/generator.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
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
        // Killer Queens with no givens has multiple solutions, so skip uniqueness check
        enforceDifficulty: false,
      );

  // Override generate to skip uniqueness checking since Killer Queens with no givens
  // has multiple valid solutions by design
  @override
  GeneratedPuzzle<KillerQueensBoard> generate({
    required String seedStr,
    required int seed64,
    required SizeOpt size,
    required DifficultyScore difficulty,
  }) {
    final SeededRng generatorRng = SeededRng(seed64);
    final generationContext = GeneratorContext(
      rng: generatorRng,
      seedStr: seedStr,
      seed64: seed64,
      size: size,
      difficulty: DifficultyRequest(
        level: difficulty.level,
        hint: difficulty.value,
      ),
    );

    final generation = generator.generate(generationContext);
    final KillerQueensBoard puzzle = generation.board;

    final ValidationSummary puzzleValidation = validator.validatePuzzle(puzzle);
    if (!puzzleValidation.isValid) {
      throw StateError(
        'Generated invalid Killer Queens puzzle for seed $seedStr: '
        '${puzzleValidation.issues.join(', ')}',
      );
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle);

    // Create a dummy solution with all queens (used for difficulty scoring)
    // In practice, multiple solutions exist
    final KillerQueensBoard dummySolution = KillerQueensBoard(
      size: puzzle.size,
      cells: List<int>.filled(puzzle.size * puzzle.size, 0),
      fixed: List<bool>.filled(puzzle.size * puzzle.size, false),
      cages: puzzle.cages,
    );

    final difficultyTelemetry = difficultyScorer.score(
      puzzle: puzzle,
      solution: dummySolution,
      context: DifficultyContext(
        generatorTelemetry: generation.snapshot.telemetry,
        solverTelemetry: const <String, Object?>{},
      ),
    );

    final String bucket = difficultyConfig.bucketFor(
      difficultyTelemetry.rawScore,
    );

    final DifficultyTelemetry normalizedTelemetry = DifficultyTelemetry(
      rawScore: difficultyTelemetry.rawScore,
      bucket: bucket,
      metrics: difficultyTelemetry.metrics,
    );

    return GeneratedPuzzle<KillerQueensBoard>(
      state: puzzle,
      meta: PuzzleMetadata(
        engineVersion: version,
        rngId: SeededRng.rngId,
        size: size,
        difficulty: DifficultyScore(
          value: normalizedTelemetry.rawScore,
          level: normalizedTelemetry.bucket,
        ),
        seedStr: seedStr,
        seed64: seed64,
      ),
      telemetry: GenerationTelemetry(
        difficulty: normalizedTelemetry,
        extras: <String, Object?>{
          'generation': generation.snapshot.telemetry,
          'solver': const <String, Object?>{},
        },
      ),
    );
  }

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
