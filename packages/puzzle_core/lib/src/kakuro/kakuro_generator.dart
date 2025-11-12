library puzzle_core_kakuro_generator;

import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/kakuro_dictionary.dart';
import '../util/seeded_rng.dart';
import 'kakuro_board.dart';
import 'kakuro_difficulty.dart';
import 'kakuro_solver.dart';

part '../generators/kakuro/layout.dart';
part '../generators/kakuro/generator_solution_first.dart';
part '../generators/kakuro/generator_bottom_up.dart';

const int _solverSalt = 0x6f95c2c1ab7342ed;
const int _mixMultiplier = 0x9e3779b97f4a7c15;
const int _mask64 = 0xffffffffffffffff;

// Difficulty profiles were used for sum-biasing; newspaper mode relies on
// solver telemetry-based gating instead of sum weighting.

int _deriveSolverSeed(int baseSeed, int attempt, int stage) {
  final int attemptSalt = (attempt * _mixMultiplier) & _mask64;
  final int combined = baseSeed ^ _solverSalt ^ attemptSalt ^ stage;
  return combined & _mask64;
}

class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator({this.maxTemplateAttempts = 160});

  final int maxTemplateAttempts;

  // Exposed for tests: map numeric and alias difficulties to normalized labels.
  static String normalizeDifficultyForTest(String raw) => _normalizeDifficulty(raw.trim().toLowerCase());

  static final DifficultyBucketConfig _difficultyConfig =
      const DifficultyConfigLoader().loadSync('assets/kakuro_difficulty_thresholds.json');

  static const KakuroDifficultyScorer _difficultyScorer = KakuroDifficultyScorer();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final String requestedLevelRaw = context.difficulty.level.trim().toLowerCase();
    final String requestedLevel = _normalizeDifficulty(requestedLevelRaw);
  // Use a strict solver (no node cap) for correctness; gating uses telemetry.
    final KakuroSolver strictSolver = const KakuroSolver(maxSearchDepth: 26);

    // Decide grid size based on difficulty. Respect provided size when present (incl. 9x9 for tests).
    final int targetWidth = _chooseWidth(context, requestedLevel);
    final int targetHeight = _chooseHeight(context, requestedLevel);
    final KakuroLayout template = KakuroLayout.buildNewspaper(
      rng: context.rng,
      width: targetWidth,
      height: targetHeight,
      difficulty: requestedLevel,
    );

    int attempts = 0;
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;

    final int multiplier = template.attemptMultiplier;
    final int attemptLimit = maxTemplateAttempts * multiplier;
    final int hardTimeBudgetMs = _timeBudgetMillis(requestedLevel);

    while (attempts < attemptLimit) {
      if (stopwatch.elapsedMilliseconds > hardTimeBudgetMs) {
        break; // time budget exceeded for this difficulty
      }
      attempts++;
      int solverStage = 0;
      SeededRng nextSolverRng() {
        solverStage++;
        return SeededRng(
          _deriveSolverSeed(context.seed64, attempts, solverStage),
        );
      }

      final KakuroSolution? solution = buildSolutionFirst(template, context.rng);
      if (solution == null) {
        continue;
      }

      // Build a pure-sums puzzle (no digit givens); verify uniqueness and logic thresholds.
      final KakuroBoard candidateBoard = template.buildBoard(
        solution.entrySums,
        const <int>{},
        null,
      );
      final SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
        candidateBoard,
        SolverContext(
          rng: nextSolverRng(),
          maxSolutions: 2,
        ),
      );
      if (!uniqueness.isUnique) {
        continue;
      }

      // Gate by backtrack/logic thresholds per difficulty.
      if (!_meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
        continue;
      }

      // Additional gating: ensure a minimum ratio of entries whose (length,sum)
      // has a single-digit-set combination. This biases toward simpler logic for easy puzzles.
      if (!_meetsSingleComboThreshold(template, candidateBoard, requestedLevel)) {
        continue;
      }

      // Score difficulty using the fast solver telemetry; engine will re-score later.
      final DifficultyTelemetry difficultyTelemetry = _difficultyScorer.score(
        puzzle: candidateBoard,
        solution: candidateBoard, // unused by scorer logic
        context: DifficultyContext(
          generatorTelemetry: <String, Object?>{
            'givens': 0,
            'valueCells': template.valueCellCount,
            'width': template.width,
            'height': template.height,
          },
          solverTelemetry: uniqueness.telemetry,
        ),
      );
      final String bucket = _difficultyConfig.bucketFor(difficultyTelemetry.rawScore);

      final Map<String, Object?> sanitizedSolverTelemetry =
          uniqueness.telemetry.map((String key, Object? value) {
        if (value is double) {
          return MapEntry<String, Object?>(key, (value * 1000).round());
        }
        return MapEntry<String, Object?>(key, value);
      });

      puzzle = candidateBoard;
      telemetry = <String, Object?>{
        'attempts': attempts,
        'attemptLimit': attemptLimit,
        'generationDurationUs': stopwatch.elapsedMicroseconds,
        'solverTelemetry': sanitizedSolverTelemetry,
        'solutionSignature': solution.signature,
        'difficultyBucket': bucket,
        'requestedDifficulty': requestedLevel,
        'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000).round(),
        'valueCellCount': template.valueCellCount,
        'givensCount': 0,
        'givenRatioMilli': 0,
        'width': template.width,
        'height': template.height,
      };
      break;
    }

    stopwatch.stop();

    if (puzzle == null) {
      // Deterministic fallback: try a few alternative layouts, then throw.
      for (int alt = 0; alt < 3 && puzzle == null; alt++) {
        final KakuroLayout altTemplate = KakuroLayout.buildNewspaper(
          rng: SeededRng(_deriveSolverSeed(context.seed64, 1234, alt + 1)),
          width: targetWidth,
          height: targetHeight,
          difficulty: requestedLevel,
        );
        final KakuroSolution? sol = buildSolutionFirst(altTemplate, context.rng);
        if (sol == null) continue;
        final KakuroBoard board = altTemplate.buildBoard(sol.entrySums);
        final SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
          board,
          SolverContext(rng: SeededRng(_deriveSolverSeed(context.seed64, 4321, alt + 1)), maxSolutions: 2),
        );
        if (uniqueness.isUnique && _meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
          puzzle = board;
          telemetry = <String, Object?>{
            'attempts': attempts,
            'attemptLimit': attemptLimit,
            'generationDurationUs': stopwatch.elapsedMicroseconds,
            'fallback': true,
            'valueCellCount': altTemplate.valueCellCount,
            'width': altTemplate.width,
            'height': altTemplate.height,
          };
        }
      }
      if (puzzle == null) {
        throw StateError('Unable to generate unique Kakuro for seed ${context.seedStr}');
      }
    }

    DeterminismGuard.assertNoFloatsOrDateTimes(telemetry);

    return PuzzleGenerationResult<KakuroBoard>(
      board: puzzle,
      snapshot: GenerationSnapshot(telemetry: telemetry),
    );
  }

  // Removal-based carving is no longer used; generation produces classic Kakuro
  // puzzles with sums only (no digit givens) and relies on uniqueness checks.
}

// Legacy candidate container removed: generation no longer uses digit givens.

// Fallback carving path removed in newspaper mode.



// Helper: difficulty normalization and grid sizing
String _normalizeDifficulty(String raw) {
  // Accept numeric shortcuts (0..3) and aliases; default to easy for 'auto'.
  switch (raw) {
    case 'auto':
      return 'easy';
    case '0':
    case 'easy':
      return 'easy';
    case '1':
    case 'medium':
      return 'medium';
    case '2':
    case 'hard':
      return 'hard';
    case '3':
    case 'expert':
      return 'expert';
    default:
      return raw; // assume known textual difficulty
  }
}

int _chooseWidth(GeneratorContext context, String level) {
  final int provided = context.size.width;
  if (provided > 0) return provided;
  switch (level) {
    case 'easy':
      return 9 + context.rng.nextIntInRange(3); // 9..11
    case 'medium':
      return 10 + context.rng.nextIntInRange(3); // 10..12
    case 'hard':
      return 12 + context.rng.nextIntInRange(3); // 12..14
    case 'expert':
      return 13 + context.rng.nextIntInRange(2); // 13..14
    default:
      return 10 + context.rng.nextIntInRange(5); // 10..14
  }
}

int _chooseHeight(GeneratorContext context, String level) {
  final int provided = context.size.height;
  if (provided > 0) return provided;
  switch (level) {
    case 'easy':
      return 9 + context.rng.nextIntInRange(3);
    case 'medium':
      return 10 + context.rng.nextIntInRange(3);
    case 'hard':
      return 12 + context.rng.nextIntInRange(3);
    case 'expert':
      return 13 + context.rng.nextIntInRange(2);
    default:
      return 10 + context.rng.nextIntInRange(5);
  }
}

int _timeBudgetMillis(String level) {
  switch (level) {
    case 'easy':
      return 900; // ~<1s target
    case 'medium':
      return 1400;
    case 'hard':
      return 2000;
    case 'expert':
      return 3000;
    default:
      return 1600;
  }
}

bool _meetsLogicThresholds(String level, Map<String, Object?> telemetry) {
  final int backtrackNodes = (telemetry['backtrackNodes'] as int?) ?? 0;
  final int propagationRounds = (telemetry['propagationRounds'] as int?) ?? 0;
  switch (level) {
    case 'easy':
      return backtrackNodes == 0 && propagationRounds <= 40;
    case 'medium':
      return backtrackNodes <= 8 && propagationRounds <= 80;
    case 'hard':
      return backtrackNodes <= 40 && propagationRounds <= 160;
    case 'expert':
      return backtrackNodes <= 120 && propagationRounds <= 360;
    default:
      return backtrackNodes <= 80;
  }
}

bool _meetsSingleComboThreshold(
  KakuroLayout template,
  KakuroBoard board,
  String level,
) {
  // Count entries whose (length,sum) combination set has exactly 1 mask.
  int singles = 0;
  for (final KakuroEntry e in board.entries) {
    final Set<int>? combos = KakuroDictionary.getCombinations(e.cells.length, e.sum);
    if (combos != null && combos.length == 1) {
      singles++;
    }
  }
  final int total = template.entries.length == 0 ? 1 : template.entries.length;
  final double ratio = singles / total;
  switch (level) {
    case 'easy':
      return ratio >= 0.12; // bias toward more forced entries
    case 'medium':
      return ratio >= 0.06;
    case 'hard':
      return ratio >= 0.02;
    case 'expert':
      return ratio >= 0.0; // no requirement; allow toughest
    default:
      return true;
  }
}





