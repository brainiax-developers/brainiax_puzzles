import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import '../validation/validator.dart';

const int _solverSalt = 0x5bf03635d8e1a1ad;

abstract class PipelinePuzzleEngine<S, M> extends PuzzleEngine<S, M> {
  PipelinePuzzleEngine({
    required this.engineId,
    required this.engineName,
    required this.engineVersion,
    required this.generator,
    required this.solver,
    required this.validator,
    required this.difficultyScorer,
    required this.difficultyConfig,
  });

  final String engineId;
  final String engineName;
  final String engineVersion;
  final PuzzleGenerator<S> generator;
  final PuzzleSolver<S> solver;
  final PuzzleValidator<S> validator;
  final DifficultyScorer<S> difficultyScorer;
  final DifficultyBucketConfig difficultyConfig;

  @override
  String get id => engineId;

  @override
  String get name => engineName;

  @override
  String get version => engineVersion;

  @override
  GeneratedPuzzle<S> generate({
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
      difficulty: DifficultyRequest(level: difficulty.level, hint: difficulty.value),
    );

    final generation = generator.generate(generationContext);
    final S puzzle = generation.board;

    final ValidationSummary puzzleValidation = validator.validatePuzzle(puzzle);
    if (!puzzleValidation.isValid) {
      throw StateError(
        'Generated puzzle failed validation for seed $seedStr: '
        '${puzzleValidation.issues.join(', ')}',
      );
    }

    final SeededRng solverRng = SeededRng(seed64 ^ _solverSalt);
    final solverResult = solver.solve(
      puzzle,
      SolverContext(rng: solverRng, maxSolutions: 2),
    );

    if (!solverResult.hasSolution) {
      throw StateError('Generated puzzle is unsolvable for seed $seedStr');
    }

    if (!solverResult.isUnique) {
      throw StateError('Generated puzzle is not unique for seed $seedStr');
    }

    final S solution = solverResult.solutions.first;
    final ValidationSummary solutionValidation =
        validator.validateSolution(puzzle, solution);
    if (!solutionValidation.isValid) {
      throw StateError(
        'Generated puzzle has invalid solution for seed $seedStr: '
        '${solutionValidation.issues.join(', ')}',
      );
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(puzzle);

    final difficultyTelemetry = difficultyScorer.score(
      puzzle: puzzle,
      solution: solution,
      context: DifficultyContext(
        generatorTelemetry: generation.snapshot.telemetry,
        solverTelemetry: solverResult.telemetry,
      ),
    );

    final String bucket = difficultyConfig.bucketFor(difficultyTelemetry.rawScore);
    final String requestedLevel = difficulty.level;
    final bool enforceDifficulty = requestedLevel.isNotEmpty &&
        difficultyConfig.buckets
            .any((DifficultyBucketThreshold threshold) => threshold.id == requestedLevel);
    if (enforceDifficulty && bucket != requestedLevel) {
      throw StateError(
        'Generated puzzle difficulty mismatch: requested $requestedLevel, got $bucket for seed $seedStr',
      );
    }
    final DifficultyTelemetry normalizedTelemetry = DifficultyTelemetry(
      rawScore: difficultyTelemetry.rawScore,
      bucket: bucket,
      metrics: difficultyTelemetry.metrics,
    );
    final DifficultyScore finalDifficulty = DifficultyScore(
      value: normalizedTelemetry.rawScore,
      level: bucket,
    );

    final PuzzleMetadata meta = PuzzleMetadata(
      engineVersion: version,
      rngId: SeededRng.rngId,
      size: size,
      difficulty: finalDifficulty,
      seedStr: seedStr,
      seed64: seed64,
    );

    final GenerationTelemetry telemetry = GenerationTelemetry(
      difficulty: normalizedTelemetry,
      extras: {
        'generator': generation.snapshot.telemetry,
        'solver': solverResult.telemetry,
        'solutionCount': solverResult.solutions.length,
        'puzzleValidationMs': puzzleValidation.elapsed.inMicroseconds / 1000.0,
        'solutionValidationMs':
            solutionValidation.elapsed.inMicroseconds / 1000.0,
      },
    );

    return GeneratedPuzzle<S>(
      state: puzzle,
      meta: meta,
      telemetry: telemetry,
    );
  }

  @override
  bool isSolved(S state) => validator.isSolved(state);
}
