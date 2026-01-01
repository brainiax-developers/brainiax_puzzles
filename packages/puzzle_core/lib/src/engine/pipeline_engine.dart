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
    this.enforceDifficulty = true,
  });

  final String engineId;
  final String engineName;
  final String engineVersion;
  final PuzzleGenerator<S> generator;
  final PuzzleSolver<S> solver;
  final PuzzleValidator<S> validator;
  final DifficultyScorer<S> difficultyScorer;
  final DifficultyBucketConfig difficultyConfig;
  final bool enforceDifficulty;

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
    // Try multiple deterministic attempts to find a puzzle that matches the requested bucket.
    // Each attempt uses a salt derived from the seed so results remain deterministic for a given seed.
    const int maxAttempts = 6;
    StateError? lastError;
    Map<String, Object?>? lastGeneratorTelemetry;
    Map<String, Object?>? lastSolverTelemetry;
    late S lastPuzzle;
    late S lastSolution;
    late ValidationSummary lastPuzzleValidation;
    late ValidationSummary lastSolutionValidation;
    late String lastBucket;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final int attemptSalt = 0x9e3779b97f4a7c15 ^ (attempt * 0x41c64e6d);
      final int attemptSeed = seed64 ^ attemptSalt;
      final SeededRng generatorRng = SeededRng(attemptSeed);
      final generationContext = GeneratorContext(
        rng: generatorRng,
        seedStr: seedStr,
        seed64: attemptSeed,
        size: size,
        difficulty:
            DifficultyRequest(level: difficulty.level, hint: difficulty.value),
      );

      final generation = generator.generate(generationContext);
      final S puzzle = generation.board;

      final ValidationSummary puzzleValidation = validator.validatePuzzle(puzzle);
      if (!puzzleValidation.isValid) {
        lastError = StateError(
          'Generated puzzle failed validation for seed $seedStr: '
          '${puzzleValidation.issues.join(', ')}',
        );
        continue; // try next attempt
      }

      final SeededRng solverRng = SeededRng(attemptSeed ^ _solverSalt);
      final solverResult = solver.solve(
        puzzle,
        SolverContext(rng: solverRng, maxSolutions: 2),
      );

      if (!solverResult.hasSolution) {
        lastError = StateError('Generated puzzle is unsolvable for seed $seedStr');
        continue;
      }

      if (!solverResult.isUnique) {
        lastError = StateError('Generated puzzle is not unique for seed $seedStr');
        continue;
      }

      final S solution = solverResult.solutions.first;
      final ValidationSummary solutionValidation =
          validator.validateSolution(puzzle, solution);
      if (!solutionValidation.isValid) {
        lastError = StateError(
          'Generated puzzle has invalid solution for seed $seedStr: '
          '${solutionValidation.issues.join(', ')}',
        );
        continue;
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

      final String bucket =
          difficultyConfig.bucketFor(difficultyTelemetry.rawScore);
      final String requestedLevel = difficulty.level;
      final bool shouldEnforce = enforceDifficulty &&
          requestedLevel.isNotEmpty &&
          difficultyConfig.buckets.any((DifficultyBucketThreshold threshold) =>
              threshold.id == requestedLevel);

      // Accept if bucket matches or enforcement is off; otherwise try next attempt.
      final bool matches = !shouldEnforce || bucket == requestedLevel;
      if (matches) {
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
            'attempt': attempt + 1,
            'generator': generation.snapshot.telemetry,
            'solver': solverResult.telemetry,
            'solutionCount': solverResult.solutions.length,
            'puzzleValidationMs':
                puzzleValidation.elapsed.inMicroseconds / 1000.0,
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

      // Keep last successful puzzle data for potential fallback if all attempts mismatch.
      lastGeneratorTelemetry = generation.snapshot.telemetry;
      lastSolverTelemetry = solverResult.telemetry;
      lastPuzzle = puzzle;
      lastSolution = solution;
      lastPuzzleValidation = puzzleValidation;
      lastSolutionValidation = solutionValidation;
      lastBucket = bucket;
    }

    // If we reach here: we couldn't satisfy the requested bucket after retries.
    // Return the last valid puzzle instead of throwing, to avoid blocking play.
    if (lastGeneratorTelemetry != null && lastSolverTelemetry != null) {
      final difficultyTelemetry = difficultyScorer.score(
        puzzle: lastPuzzle,
        solution: lastSolution,
        context: DifficultyContext(
          generatorTelemetry: lastGeneratorTelemetry,
          solverTelemetry: lastSolverTelemetry,
        ),
      );
      final DifficultyTelemetry normalizedTelemetry = DifficultyTelemetry(
        rawScore: difficultyTelemetry.rawScore,
        bucket: lastBucket,
        metrics: difficultyTelemetry.metrics,
      );
      final DifficultyScore finalDifficulty = DifficultyScore(
        value: normalizedTelemetry.rawScore,
        level: lastBucket,
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
          'attempt': maxAttempts,
          'generator': lastGeneratorTelemetry,
          'solver': lastSolverTelemetry,
          'solutionCount': 1,
          'puzzleValidationMs':
              lastPuzzleValidation.elapsed.inMicroseconds / 1000.0,
          'solutionValidationMs':
              lastSolutionValidation.elapsed.inMicroseconds / 1000.0,
          'warning':
              'difficulty_mismatch_after_retries_returning_best_effort',
      },
      );

      return GeneratedPuzzle<S>(
        state: lastPuzzle,
        meta: meta,
        telemetry: telemetry,
      );
    }

    // No valid puzzle was found at all; throw the last error.
    throw lastError ?? StateError('Failed to generate puzzle for seed $seedStr');
  }

  @override
  bool isSolved(S state) => validator.isSolved(state);
}
