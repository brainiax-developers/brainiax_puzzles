library puzzle_core_kakuro_generator;

import 'dart:math' as math;

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

int _deriveSolverSeed(int baseSeed, int attempt, int stage) {
  final int attemptSalt = (attempt * _mixMultiplier) & _mask64;
  final int combined = baseSeed ^ _solverSalt ^ attemptSalt ^ stage;
  return combined & _mask64;
}

/// Kakuro generator used by the engine and on-demand flows.
///
/// The generator builds a random "newspaper-style" layout, seeds a fully solved
/// board, and then gates the candidate puzzle through uniqueness and difficulty
/// checks. Time budgets are enforced to keep UI flows responsive.
class KakuroGenerator extends PuzzleGenerator<KakuroBoard> {
  const KakuroGenerator({
    this.maxTemplateAttempts = 160,
    this.hardTimeLimitOverride,
    this.maxSearchDepth = 22,
    this.maxBacktrackNodes = 9000,
    this.perAttemptTimeLimit = const Duration(milliseconds: 1100),
  });

  final int maxTemplateAttempts;
  final Duration? hardTimeLimitOverride;
  final int maxSearchDepth;
  final int maxBacktrackNodes;
  final Duration perAttemptTimeLimit;

  // Convenience for callers that want to reuse the same tuning while applying
  // a tighter time budget (e.g., on-demand service).
  KakuroGenerator copyWith({Duration? hardTimeLimit}) {
    return KakuroGenerator(
      maxTemplateAttempts: maxTemplateAttempts,
      hardTimeLimitOverride: hardTimeLimit ?? hardTimeLimitOverride,
      maxSearchDepth: maxSearchDepth,
      maxBacktrackNodes: maxBacktrackNodes,
      perAttemptTimeLimit: perAttemptTimeLimit,
    );
  }

  // Exposed for tests: map numeric and alias difficulties to normalized labels.
  static String normalizeDifficultyForTest(String raw) =>
      _normalizeDifficulty(raw.trim().toLowerCase());

  static final DifficultyBucketConfig _difficultyConfig =
      const DifficultyConfigLoader()
          .loadSync('assets/kakuro_difficulty_thresholds.json');

  static const KakuroDifficultyScorer _difficultyScorer =
      KakuroDifficultyScorer();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    final DateTime startedAt = DateTime.now();
    final Stopwatch stopwatch = Stopwatch()..start();
    final String requestedLevelRaw = context.difficulty.level.trim().toLowerCase();
    final String requestedLevel = _normalizeDifficulty(requestedLevelRaw);

    final KakuroSolver strictSolver = KakuroSolver(
      maxSearchDepth: maxSearchDepth,
      maxBacktrackNodes: maxBacktrackNodes,
    );

    final Stopwatch layoutWatch = Stopwatch()..start();
    // Decide grid size based on difficulty. Respect provided size when present.
    final int targetWidth = _chooseWidth(context, requestedLevel);
    final int targetHeight = _chooseHeight(context, requestedLevel);
    final KakuroLayout template = KakuroLayout.buildNewspaper(
      rng: context.rng,
      width: targetWidth,
      height: targetHeight,
      difficulty: requestedLevel,
    );
    layoutWatch.stop();

    int attempts = 0;
    int nullSolutionCount = 0;
    int nonUniqueCount = 0;
    int logicRejectCount = 0;
    int comboRejectCount = 0;
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;

    final int attemptLimit = maxTemplateAttempts * template.attemptMultiplier;
    final int hardTimeBudgetMs = _effectiveTimeBudgetMs(requestedLevel);
    final int perAttemptBudgetMs = perAttemptTimeLimit.inMilliseconds;

    while (attempts < attemptLimit) {
      if (stopwatch.elapsedMilliseconds > hardTimeBudgetMs) {
        break; // global time budget exceeded
      }
      attempts++;
      final Stopwatch attemptWatch = Stopwatch()..start();
      int solverStage = 0;
      SeededRng nextSolverRng() {
        solverStage++;
        return SeededRng(
          _deriveSolverSeed(context.seed64, attempts, solverStage),
        );
      }

      // Build a fully solved board using the fast solution-first generator.
      final Stopwatch candidateBuildWatch = Stopwatch()..start();
      KakuroSolution? solution = buildSolutionFirst(template, context.rng);
      // If the initial approach fails quickly, try the bottom-up generator once
      // before moving to the next attempt.
      if (solution == null && attemptWatch.elapsedMilliseconds < perAttemptBudgetMs ~/ 2) {
        solution = const KakuroBottomUpGenerator().generate(template, context.rng);
      }
      candidateBuildWatch.stop();
      if (solution == null) {
        nullSolutionCount++;
        continue;
      }

      // Add a handful of digit givens (tuned per difficulty) to improve
      // uniqueness rates without reducing challenge.
      final Set<int> givenCells =
          _selectGivenCells(template, context.rng, requestedLevel);

      // Build a puzzle board with sums and optional givens; verify uniqueness and logic thresholds.
      final KakuroBoard candidateBoard = template.buildBoard(
        solution.entrySums,
        givenCells,
        solution.values,
      );

      final Stopwatch solverWatch = Stopwatch()..start();
      final SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
        candidateBoard,
        SolverContext(
          rng: nextSolverRng(),
          maxSolutions: 2,
        ),
      );
      solverWatch.stop();

      final int attemptMs = attemptWatch.elapsedMilliseconds;
      if (attemptMs > perAttemptBudgetMs &&
          uniqueness.solutionStatus != SolverStatus.unique) {
        // Skip long-running, non-unique attempts early to respect budgets.
        nonUniqueCount++;
        continue;
      }
      if (uniqueness.solutionStatus != SolverStatus.unique) {
        nonUniqueCount++;
        continue;
      }

      // Gate by backtrack/logic thresholds per difficulty.
      if (!_meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
        logicRejectCount++;
        continue;
      }

      // Additional gating: ensure a minimum ratio of entries whose (length,sum)
      // has a single-digit-set combination. This biases toward simpler logic for easy puzzles.
      if (!_meetsSingleComboThreshold(template, candidateBoard, requestedLevel)) {
        comboRejectCount++;
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
        'generationDurationMs': stopwatch.elapsedMilliseconds,
        'attemptDurationMs': attemptMs,
        'layoutMs': layoutWatch.elapsedMilliseconds,
        'candidateBuildMs': candidateBuildWatch.elapsedMilliseconds,
        'solverMs': solverWatch.elapsedMilliseconds,
        'solverTelemetry': sanitizedSolverTelemetry,
        'difficultyBucket': bucket,
        'requestedDifficulty': requestedLevel,
        'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000).round(),
        'valueCellCount': template.valueCellCount,
        'givensCount': givenCells.length,
        'givenRatioMilli': template.valueCellCount == 0
            ? 0
            : givenCells.length * 1000 ~/ template.valueCellCount,
        'width': template.width,
        'height': template.height,
        'perAttemptBudgetMs': perAttemptBudgetMs,
        'hardBudgetMs': hardTimeBudgetMs,
        'startedAt': startedAt.toIso8601String(),
        'rejectCounters': <String, int>{
          'nullCandidate': nullSolutionCount,
          'nonUnique': nonUniqueCount,
          'logicGate': logicRejectCount,
          'comboGate': comboRejectCount,
        },
      };
      break;
    }

    stopwatch.stop();

    if (puzzle == null) {
      // Deterministic fallback: try a few alternative layouts within the remaining budget.
      for (int alt = 0; alt < 2 && puzzle == null; alt++) {
        if (stopwatch.elapsedMilliseconds > hardTimeBudgetMs) break;
        final KakuroLayout altTemplate = KakuroLayout.buildNewspaper(
          rng: SeededRng(_deriveSolverSeed(context.seed64, 1234, alt + 1)),
          width: targetWidth,
          height: targetHeight,
          difficulty: requestedLevel,
        );
        final KakuroSolution? sol =
            buildSolutionFirst(altTemplate, context.rng);
        if (sol == null) continue;
        final KakuroBoard board = altTemplate.buildBoard(sol.entrySums);
        final SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
          board,
          SolverContext(
            rng: SeededRng(
              _deriveSolverSeed(context.seed64, 4321, alt + 1),
            ),
            maxSolutions: 2,
          ),
        );
        if (uniqueness.solutionStatus == SolverStatus.unique &&
            _meetsLogicThresholds(requestedLevel, uniqueness.telemetry) &&
            _meetsSingleComboThreshold(altTemplate, board, requestedLevel)) {
          puzzle = board;
          telemetry = <String, Object?>{
            'attempts': attempts,
            'attemptLimit': attemptLimit,
            'generationDurationMs': stopwatch.elapsedMilliseconds,
            'fallback': true,
            'valueCellCount': altTemplate.valueCellCount,
            'width': altTemplate.width,
            'height': altTemplate.height,
            'rejectCounters': <String, int>{
              'nullCandidate': nullSolutionCount,
              'nonUnique': nonUniqueCount,
              'logicGate': logicRejectCount,
              'comboGate': comboRejectCount,
            },
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

  int _effectiveTimeBudgetMs(String level) {
    final int base = _timeBudgetMillis(level);
    if (hardTimeLimitOverride != null) {
      return math.min(base, hardTimeLimitOverride!.inMilliseconds);
    }
    return base;
  }
}

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

Set<int> _selectGivenCells(
  KakuroLayout template,
  SeededRng rng,
  String level,
) {
  int minGivens;
  int maxGivens;
  switch (level) {
    case 'easy':
      minGivens = 2;
      maxGivens = 4;
      break;
    case 'medium':
      minGivens = 1;
      maxGivens = 3;
      break;
    case 'hard':
      minGivens = 0;
      maxGivens = 1;
      break;
    case 'expert':
      minGivens = 0;
      maxGivens = 0;
      break;
    default:
      minGivens = 1;
      maxGivens = 2;
  }
  final int valueCount = template.valueCells.length;
  final int span = math.max(0, maxGivens - minGivens + 1);
  final int target = math.min(
    valueCount,
    minGivens + (span == 0 ? 0 : rng.nextIntInRange(span)),
  );
  if (target <= 0) {
    return const <int>{};
  }
  final List<int> order = rng.permute(template.valueCells);
  return order.take(target).toSet();
}

int _timeBudgetMillis(String level) {
  switch (level) {
    case 'easy':
      return 2000; // still well under prior 20s baseline
    case 'medium':
      return 2600;
    case 'hard':
      return 3200;
    case 'expert':
      return 4000;
    default:
      return 2600;
  }
}

bool _meetsLogicThresholds(String level, Map<String, Object?> telemetry) {
  final int backtrackNodes = (telemetry['backtrackNodes'] as int?) ?? 0;
  final int propagationRounds = (telemetry['propagationRounds'] as int?) ?? 0;
  switch (level) {
    case 'easy':
      return backtrackNodes <= 12 && propagationRounds <= 80;
    case 'medium':
      return backtrackNodes <= 40 && propagationRounds <= 140;
    case 'hard':
      return backtrackNodes <= 120 && propagationRounds <= 260;
    case 'expert':
      return backtrackNodes <= 280 && propagationRounds <= 520;
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
  final int total = template.entries.isEmpty ? 1 : template.entries.length;
  final double ratio = singles / total;
  switch (level) {
    case 'easy':
      return ratio >= 0.08; // bias toward more forced entries
    case 'medium':
      return ratio >= 0.04;
    case 'hard':
      return ratio >= 0.01;
    case 'expert':
      return ratio >= 0.0; // no requirement; allow toughest
    default:
      return true;
  }
}
