library puzzle_core_kakuro_generator;

import 'dart:math' as math;

import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../generators/generator.dart';
import '../generators/kakuro/models.dart';
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
    this.layoutPreScorer = const KakuroLayoutPreScorer(),
  });

  final int maxTemplateAttempts;
  final Duration? hardTimeLimitOverride;
  final int maxSearchDepth;
  final int maxBacktrackNodes;
  final Duration perAttemptTimeLimit;
  final KakuroLayoutPreScorer layoutPreScorer;

  // Convenience for callers that want to reuse the same tuning while applying
  // a tighter time budget (e.g., on-demand service).
  KakuroGenerator copyWith({Duration? hardTimeLimit}) {
    return KakuroGenerator(
      maxTemplateAttempts: maxTemplateAttempts,
      hardTimeLimitOverride: hardTimeLimit ?? hardTimeLimitOverride,
      maxSearchDepth: maxSearchDepth,
      maxBacktrackNodes: maxBacktrackNodes,
      perAttemptTimeLimit: perAttemptTimeLimit,
      layoutPreScorer: layoutPreScorer,
    );
  }

  // Exposed for tests: map numeric and alias difficulties to normalized labels.
  static String normalizeDifficultyForTest(String raw) =>
      _normalizeDifficulty(raw.trim().toLowerCase());

  static final DifficultyBucketConfig _difficultyConfig =
      const DifficultyConfigLoader().loadSync(
        'assets/kakuro_difficulty_thresholds.json',
      );

  static const KakuroDifficultyScorer _difficultyScorer =
      KakuroDifficultyScorer();

  @override
  PuzzleGenerationResult<KakuroBoard> generate(GeneratorContext context) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final String requestedLevelRaw = context.difficulty.level
        .trim()
        .toLowerCase();
    final String requestedLevel = _normalizeDifficulty(requestedLevelRaw);

    final KakuroSolver strictSolver = KakuroSolver(
      maxSearchDepth: maxSearchDepth,
      maxBacktrackNodes: maxBacktrackNodes,
    );
    final KakuroSolver exhaustiveFallbackSolver = KakuroSolver(
      maxSearchDepth: math.max(maxSearchDepth, 32),
      maxBacktrackNodes: maxBacktrackNodes * 6,
    );

    int attempts = 0;
    int fallbackAttempts = 0;
    int nullSolutionCount = 0;
    int layoutGateRejectCount = 0;
    int nonUniqueCount = 0;
    int unknownStatusCount = 0;
    int logicRejectCount = 0;
    int comboRejectCount = 0;
    int attemptBudgetExceededCount = 0;
    int hardBudgetExceededCount = 0;
    final Map<String, int> layoutGateReasonCounts = <String, int>{};
    String layoutGateReason = 'not_scored';
    int layoutScoreMilli = 0;
    KakuroLayoutMetrics? selectedLayoutMetrics;
    final List<Map<String, Object?>> attemptLog = <Map<String, Object?>>[];
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;
    String? terminalFailureReason;

    // Respect the requested phone-supported square size.
    final int targetWidth = _chooseWidth(context, requestedLevel);
    final int targetHeight = _chooseHeight(context, requestedLevel);
    final int hardTimeBudgetMs = _effectiveTimeBudgetMs(requestedLevel);
    final int perAttemptBudgetMs = perAttemptTimeLimit.inMilliseconds;

    bool overHardBudget() => stopwatch.elapsedMilliseconds >= hardTimeBudgetMs;

    void recordAttempt({
      required int attempt,
      required int durationMs,
      required String outcome,
      String? rejectReason,
      String? solverStatus,
      String? mode,
    }) {
      attemptLog.add(<String, Object?>{
        'attempt': attempt,
        'durationMs': durationMs,
        'outcome': outcome,
        if (rejectReason != null) 'rejectReason': rejectReason,
        if (solverStatus != null) 'solverStatus': solverStatus,
        if (mode != null) 'mode': mode,
      });
    }

    final Stopwatch layoutWatch = Stopwatch()..start();
    final Stopwatch layoutScoreWatch = Stopwatch();
    final int maxLayoutCandidates = _layoutCandidateBudgetFor(
      width: targetWidth,
      height: targetHeight,
      difficulty: requestedLevel,
    );
    KakuroLayout? template;
    for (
      int candidateIndex = 0;
      candidateIndex < maxLayoutCandidates;
      candidateIndex++
    ) {
      if (overHardBudget()) {
        hardBudgetExceededCount++;
        terminalFailureReason = 'hard_budget_exceeded';
        break;
      }
      final KakuroLayout candidate = KakuroLayout.buildNewspaper(
        rng: context.rng,
        width: targetWidth,
        height: targetHeight,
        difficulty: requestedLevel,
      );
      layoutScoreWatch.start();
      final KakuroLayoutPreScoreResult preScore = layoutPreScorer.score(
        layout: candidate,
        difficulty: requestedLevel,
      );
      layoutScoreWatch.stop();
      layoutScoreMilli = preScore.scoreMilli;
      selectedLayoutMetrics = preScore.metrics;
      if (preScore.accepted) {
        template = candidate;
        layoutGateReason = preScore.reason;
        break;
      }
      layoutGateRejectCount++;
      layoutGateReason = preScore.reason;
      layoutGateReasonCounts[preScore.reason] =
          (layoutGateReasonCounts[preScore.reason] ?? 0) + 1;
    }
    layoutWatch.stop();
    final int layoutScoreMs = layoutScoreWatch.elapsedMilliseconds;
    if (template == null) {
      terminalFailureReason ??= 'layout_gate_exhausted';
    }
    final int attemptMultiplier = targetWidth <= 5
        ? 3
        : (targetWidth <= 7 ? 8 : 10);
    final int attemptLimit = maxTemplateAttempts * attemptMultiplier;

    GenerationFailure generationFailure({
      required String message,
      required String reason,
    }) {
      stopwatch.stop();
      return GenerationFailure(
        message: message,
        attempts: attempts + fallbackAttempts,
        elapsed: stopwatch.elapsed,
        baseSeed: context.seed64,
        context: <String, Object?>{
          'failureReason': reason,
          'requestedDifficulty': requestedLevel,
          'selectedSize': '${targetWidth}x$targetHeight',
          'attemptLimit': attemptLimit,
          'hardBudgetMs': hardTimeBudgetMs,
          'perAttemptBudgetMs': perAttemptBudgetMs,
          'rejectCounters': <String, int>{
            'nullCandidate': nullSolutionCount,
            'layoutGate': layoutGateRejectCount,
            'nonUnique': nonUniqueCount,
            'unknownStatus': unknownStatusCount,
            'logicGate': logicRejectCount,
            'comboGate': comboRejectCount,
            'attemptBudget': attemptBudgetExceededCount,
            'hardBudget': hardBudgetExceededCount,
          },
          'layoutScoreMilli': layoutScoreMilli,
          'layoutGateReason': layoutGateReason,
          'layoutGateReasonCounts': layoutGateReasonCounts,
          'attemptsLog': attemptLog,
        },
      );
    }

    if (template == null) {
      throw generationFailure(
        message: 'Unable to find Kakuro layout passing pre-score gate',
        reason: terminalFailureReason ?? 'layout_gate_exhausted',
      );
    }
    final KakuroLayout selectedTemplate = template;
    selectedLayoutMetrics ??= selectedTemplate.computeMetrics();

    while (attempts < attemptLimit) {
      if (overHardBudget()) {
        hardBudgetExceededCount++;
        terminalFailureReason = 'hard_budget_exceeded';
        break;
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
      final Stopwatch fillWatch = Stopwatch()..start();
      KakuroSolution? solution = buildSolutionFirst(
        selectedTemplate,
        SeededRng(_deriveSolverSeed(context.seed64, attempts, 1001)),
      );
      // If the initial approach fails, try the bottom-up generator once before
      // moving to the next attempt.
      if (solution == null) {
        solution = const KakuroBottomUpGenerator().generate(
          selectedTemplate,
          SeededRng(_deriveSolverSeed(context.seed64, attempts, 1002)),
        );
      }
      fillWatch.stop();
      if (solution == null) {
        nullSolutionCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptWatch.elapsedMilliseconds,
          outcome: 'rejected',
          rejectReason: 'null_candidate',
          mode: 'primary',
        );
        continue;
      }

      if (attemptWatch.elapsedMilliseconds > perAttemptBudgetMs) {
        attemptBudgetExceededCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptWatch.elapsedMilliseconds,
          outcome: 'rejected',
          rejectReason: 'attempt_budget_exceeded_after_candidate',
          mode: 'primary',
        );
        continue;
      }

      final Stopwatch clueBuildWatch = Stopwatch()..start();
      // Production Kakuro starts with empty playable cells. Uniqueness must
      // come from layout and clue constraints, not hidden answer givens.
      final KakuroBoard candidateBoard = selectedTemplate.buildBoard(
        solution.entrySums,
      );
      clueBuildWatch.stop();

      final Stopwatch uniquenessSolveWatch = Stopwatch()..start();
      SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
        candidateBoard,
        SolverContext(rng: nextSolverRng(), maxSolutions: 2),
      );
      if (uniqueness.solutionStatus == SolverStatus.unknown) {
        uniqueness = exhaustiveFallbackSolver.solve(
          candidateBoard,
          SolverContext(rng: nextSolverRng(), maxSolutions: 2),
        );
      }
      uniquenessSolveWatch.stop();

      final int attemptMs = attemptWatch.elapsedMilliseconds;
      if (overHardBudget()) {
        hardBudgetExceededCount++;
        terminalFailureReason = 'hard_budget_exceeded';
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'rejected',
          rejectReason: 'hard_budget_exceeded',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
        );
        break;
      }
      if (attemptMs > perAttemptBudgetMs) {
        attemptBudgetExceededCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'rejected',
          rejectReason: 'attempt_budget_exceeded_after_solver',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
        );
        continue;
      }
      if (uniqueness.solutionStatus == SolverStatus.unknown) {
        unknownStatusCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'rejected',
          rejectReason: 'solver_status_unknown',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
        );
        continue;
      }
      if (uniqueness.solutionStatus != SolverStatus.unique) {
        nonUniqueCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'rejected',
          rejectReason: 'non_unique',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
        );
        continue;
      }

      // Gate by backtrack/logic thresholds per difficulty.
      if (!_meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
        logicRejectCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'rejected',
          rejectReason: 'logic_gate',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
        );
        continue;
      }

      // Additional gating: ensure a minimum ratio of entries whose (length,sum)
      // has a single-digit-set combination. This biases toward simpler logic for easy puzzles.
      if (!_meetsSingleComboThreshold(
        selectedTemplate,
        candidateBoard,
        requestedLevel,
      )) {
        comboRejectCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'rejected',
          rejectReason: 'combo_gate',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
        );
        continue;
      }

      // Score difficulty using the fast solver telemetry; engine will re-score later.
      final Stopwatch difficultyScoreWatch = Stopwatch()..start();
      final DifficultyTelemetry difficultyTelemetry = _difficultyScorer.score(
        puzzle: candidateBoard,
        solution: candidateBoard, // unused by scorer logic
        context: DifficultyContext(
          generatorTelemetry: <String, Object?>{
            'givens': 0,
            'valueCells': selectedTemplate.valueCellCount,
            'width': selectedTemplate.width,
            'height': selectedTemplate.height,
          },
          solverTelemetry: uniqueness.telemetry,
        ),
      );
      difficultyScoreWatch.stop();
      final String bucket = _difficultyConfig.bucketFor(
        difficultyTelemetry.rawScore,
      );
      final Map<String, Object?> structuralTelemetry = selectedTemplate
          .buildStructuralTelemetry(entrySums: solution.entrySums);

      final Map<String, Object?> sanitizedSolverTelemetry = uniqueness.telemetry
          .map((String key, Object? value) {
            if (value is double) {
              return MapEntry<String, Object?>(key, (value * 1000).round());
            }
            return MapEntry<String, Object?>(key, value);
          });

      puzzle = candidateBoard;
      recordAttempt(
        attempt: attempts,
        durationMs: attemptMs,
        outcome: 'accepted',
        solverStatus: uniqueness.solutionStatus.name,
        mode: 'primary',
      );
      telemetry = <String, Object?>{
        'attempts': attempts + fallbackAttempts,
        'attemptLimit': attemptLimit,
        'generationDurationMs': stopwatch.elapsedMilliseconds,
        'stageTimingMs': <String, int>{
          'layout': layoutWatch.elapsedMilliseconds,
          'layoutScore': layoutScoreMs,
          'fill': fillWatch.elapsedMilliseconds,
          'clueBuild': clueBuildWatch.elapsedMilliseconds,
          'uniquenessSolve': uniquenessSolveWatch.elapsedMilliseconds,
          'difficultyScore': difficultyScoreWatch.elapsedMilliseconds,
          'total': stopwatch.elapsedMilliseconds,
        },
        'attemptDurationMs': attemptMs,
        'layoutMs': layoutWatch.elapsedMilliseconds,
        'candidateBuildMs': fillWatch.elapsedMilliseconds,
        'solverMs': uniquenessSolveWatch.elapsedMilliseconds,
        'solverTelemetry': sanitizedSolverTelemetry,
        'measuredDifficultyBucket': bucket,
        'difficultyBucket': bucket,
        'requestedDifficulty': requestedLevel,
        'difficultyMatchedRequest': bucket == requestedLevel,
        'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000).round(),
        'selectedSize': '${selectedTemplate.width}x${selectedTemplate.height}',
        'valueCellCount': selectedTemplate.valueCellCount,
        // Kept for telemetry compatibility; generated starts no longer include
        // digit givens.
        'givensCount': 0,
        'givenRatioMilli': 0,
        'width': selectedTemplate.width,
        'height': selectedTemplate.height,
        'layoutScoreMilli': layoutScoreMilli,
        'layoutGateReason': layoutGateReason,
        'layoutGateReasonCounts': layoutGateReasonCounts,
        ...selectedLayoutMetrics!.toTelemetry(),
        ...structuralTelemetry,
        'perAttemptBudgetMs': perAttemptBudgetMs,
        'hardBudgetMs': hardTimeBudgetMs,
        'hardCapExceeded': false,
        'attemptsLog': attemptLog,
        'rejectCounters': <String, int>{
          'nullCandidate': nullSolutionCount,
          'layoutGate': layoutGateRejectCount,
          'nonUnique': nonUniqueCount,
          'unknownStatus': unknownStatusCount,
          'logicGate': logicRejectCount,
          'comboGate': comboRejectCount,
          'attemptBudget': attemptBudgetExceededCount,
          'hardBudget': hardBudgetExceededCount,
        },
      };
      break;
    }

    if (puzzle == null) {
      // Deterministic fallback: try a few alternative layouts and candidate
      // seeds before failing the request.
      for (int alt = 0; alt < 8 && puzzle == null; alt++) {
        if (overHardBudget()) {
          hardBudgetExceededCount++;
          terminalFailureReason = 'hard_budget_exceeded';
          break;
        }
        fallbackAttempts++;
        final int attemptNumber = attempts + fallbackAttempts;
        final Stopwatch attemptWatch = Stopwatch()..start();
        final KakuroLayout altTemplate = KakuroLayout.buildNewspaper(
          rng: SeededRng(_deriveSolverSeed(context.seed64, 1234, alt + 1)),
          width: targetWidth,
          height: targetHeight,
          difficulty: requestedLevel,
        );
        final KakuroLayoutPreScoreResult preScore = layoutPreScorer.score(
          layout: altTemplate,
          difficulty: requestedLevel,
        );
        layoutScoreMilli = preScore.scoreMilli;
        layoutGateReason = preScore.reason;
        if (!preScore.accepted) {
          layoutGateRejectCount++;
          layoutGateReasonCounts[preScore.reason] =
              (layoutGateReasonCounts[preScore.reason] ?? 0) + 1;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'layout_gate_${preScore.reason}',
            mode: 'fallback_strict',
          );
          continue;
        }
        final KakuroLayoutMetrics altMetrics = preScore.metrics;
        KakuroSolution? sol = buildSolutionFirst(
          altTemplate,
          SeededRng(_deriveSolverSeed(context.seed64, 2234, alt + 1)),
        );
        sol ??= const KakuroBottomUpGenerator().generate(
          altTemplate,
          SeededRng(_deriveSolverSeed(context.seed64, 2234, alt + 101)),
        );
        if (sol == null) {
          nullSolutionCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'null_candidate',
            mode: 'fallback_strict',
          );
          continue;
        }
        final KakuroBoard board = altTemplate.buildBoard(sol.entrySums);
        SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
          board,
          SolverContext(
            rng: SeededRng(_deriveSolverSeed(context.seed64, 4321, alt + 1)),
            maxSolutions: 2,
          ),
        );
        if (uniqueness.solutionStatus == SolverStatus.unknown) {
          uniqueness = exhaustiveFallbackSolver.solve(
            board,
            SolverContext(
              rng: SeededRng(
                _deriveSolverSeed(context.seed64, 4321, alt + 101),
              ),
              maxSolutions: 2,
            ),
          );
        }
        final int attemptMs = attemptWatch.elapsedMilliseconds;
        if (overHardBudget()) {
          hardBudgetExceededCount++;
          terminalFailureReason = 'hard_budget_exceeded';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'hard_budget_exceeded',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
          );
          break;
        }
        if (attemptMs > perAttemptBudgetMs) {
          attemptBudgetExceededCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'attempt_budget_exceeded_after_solver',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
          );
          continue;
        }
        if (uniqueness.solutionStatus == SolverStatus.unknown) {
          unknownStatusCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'solver_status_unknown',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
          );
          continue;
        }
        if (uniqueness.solutionStatus != SolverStatus.unique) {
          nonUniqueCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'non_unique',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
          );
          continue;
        }
        if (!_meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
          logicRejectCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'logic_gate',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
          );
          continue;
        }
        if (!_meetsSingleComboThreshold(altTemplate, board, requestedLevel)) {
          comboRejectCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'combo_gate',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
          );
          continue;
        }
        if (uniqueness.solutionStatus == SolverStatus.unique) {
          final Stopwatch difficultyScoreWatch = Stopwatch()..start();
          final DifficultyTelemetry difficultyTelemetry = _difficultyScorer
              .score(
                puzzle: board,
                solution: board,
                context: DifficultyContext(
                  generatorTelemetry: <String, Object?>{
                    'valueCells': altTemplate.valueCellCount,
                    'width': altTemplate.width,
                    'height': altTemplate.height,
                  },
                  solverTelemetry: uniqueness.telemetry,
                ),
              );
          difficultyScoreWatch.stop();
          final String bucket = _difficultyConfig.bucketFor(
            difficultyTelemetry.rawScore,
          );
          final Map<String, Object?> structuralTelemetry = altTemplate
              .buildStructuralTelemetry(entrySums: sol.entrySums);
          puzzle = board;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'accepted',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
          );
          telemetry = <String, Object?>{
            'attempts': attempts + fallbackAttempts,
            'attemptLimit': attemptLimit,
            'generationDurationMs': stopwatch.elapsedMilliseconds,
            'fallback': true,
            'fallbackMode': 'strict',
            'stageTimingMs': <String, int>{
              'layout': layoutWatch.elapsedMilliseconds,
              'layoutScore': layoutScoreMs,
              'fill': attemptMs,
              'clueBuild': 0,
              'uniquenessSolve': 0,
              'difficultyScore': difficultyScoreWatch.elapsedMilliseconds,
              'total': stopwatch.elapsedMilliseconds,
            },
            'measuredDifficultyBucket': bucket,
            'difficultyBucket': bucket,
            'requestedDifficulty': requestedLevel,
            'difficultyMatchedRequest': bucket == requestedLevel,
            'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000)
                .round(),
            'selectedSize': '${altTemplate.width}x${altTemplate.height}',
            'valueCellCount': altTemplate.valueCellCount,
            // Kept for telemetry compatibility; generated starts no longer
            // include digit givens.
            'givensCount': 0,
            'givenRatioMilli': 0,
            'width': altTemplate.width,
            'height': altTemplate.height,
            'layoutScoreMilli': layoutScoreMilli,
            'layoutGateReason': layoutGateReason,
            'layoutGateReasonCounts': layoutGateReasonCounts,
            ...altMetrics.toTelemetry(),
            ...structuralTelemetry,
            'perAttemptBudgetMs': perAttemptBudgetMs,
            'hardBudgetMs': hardTimeBudgetMs,
            'hardCapExceeded': false,
            'attemptsLog': attemptLog,
            'rejectCounters': <String, int>{
              'nullCandidate': nullSolutionCount,
              'layoutGate': layoutGateRejectCount,
              'nonUnique': nonUniqueCount,
              'unknownStatus': unknownStatusCount,
              'logicGate': logicRejectCount,
              'comboGate': comboRejectCount,
              'attemptBudget': attemptBudgetExceededCount,
              'hardBudget': hardBudgetExceededCount,
            },
          };
        }
      }
      if (puzzle == null) {
        // Last-resort deterministic fallback: accept any unique puzzle if
        // calibrated gates cannot be satisfied within budget.
        for (int alt = 0; alt < 24 && puzzle == null; alt++) {
          if (overHardBudget()) {
            hardBudgetExceededCount++;
            terminalFailureReason = 'hard_budget_exceeded';
            break;
          }
          fallbackAttempts++;
          final int attemptNumber = attempts + fallbackAttempts;
          final Stopwatch attemptWatch = Stopwatch()..start();
          final KakuroLayout altTemplate = KakuroLayout.buildNewspaper(
            rng: SeededRng(_deriveSolverSeed(context.seed64, 8128, alt + 1)),
            width: targetWidth,
            height: targetHeight,
            difficulty: requestedLevel,
          );
          final KakuroLayoutPreScoreResult preScore = layoutPreScorer.score(
            layout: altTemplate,
            difficulty: requestedLevel,
          );
          layoutScoreMilli = preScore.scoreMilli;
          layoutGateReason = preScore.reason;
          if (!preScore.accepted) {
            layoutGateRejectCount++;
            layoutGateReasonCounts[preScore.reason] =
                (layoutGateReasonCounts[preScore.reason] ?? 0) + 1;
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptWatch.elapsedMilliseconds,
              outcome: 'rejected',
              rejectReason: 'layout_gate_${preScore.reason}',
              mode: 'fallback_relaxed',
            );
            continue;
          }
          final KakuroLayoutMetrics altMetrics = preScore.metrics;
          KakuroSolution? sol = buildSolutionFirst(
            altTemplate,
            SeededRng(_deriveSolverSeed(context.seed64, 9128, alt + 1)),
          );
          sol ??= const KakuroBottomUpGenerator().generate(
            altTemplate,
            SeededRng(_deriveSolverSeed(context.seed64, 9128, alt + 101)),
          );
          if (sol == null) {
            nullSolutionCount++;
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptWatch.elapsedMilliseconds,
              outcome: 'rejected',
              rejectReason: 'null_candidate',
              mode: 'fallback_relaxed',
            );
            continue;
          }

          final KakuroBoard board = altTemplate.buildBoard(sol.entrySums);
          SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
            board,
            SolverContext(
              rng: SeededRng(_deriveSolverSeed(context.seed64, 9917, alt + 1)),
              maxSolutions: 2,
            ),
          );
          if (uniqueness.solutionStatus == SolverStatus.unknown) {
            uniqueness = exhaustiveFallbackSolver.solve(
              board,
              SolverContext(
                rng: SeededRng(
                  _deriveSolverSeed(context.seed64, 9917, alt + 101),
                ),
                maxSolutions: 2,
              ),
            );
          }
          final int attemptMs = attemptWatch.elapsedMilliseconds;
          if (overHardBudget()) {
            hardBudgetExceededCount++;
            terminalFailureReason = 'hard_budget_exceeded';
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptMs,
              outcome: 'rejected',
              rejectReason: 'hard_budget_exceeded',
              solverStatus: uniqueness.solutionStatus.name,
              mode: 'fallback_relaxed',
            );
            break;
          }
          if (attemptMs > perAttemptBudgetMs) {
            attemptBudgetExceededCount++;
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptMs,
              outcome: 'rejected',
              rejectReason: 'attempt_budget_exceeded_after_solver',
              solverStatus: uniqueness.solutionStatus.name,
              mode: 'fallback_relaxed',
            );
            continue;
          }
          if (uniqueness.solutionStatus == SolverStatus.unknown) {
            unknownStatusCount++;
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptMs,
              outcome: 'rejected',
              rejectReason: 'solver_status_unknown',
              solverStatus: uniqueness.solutionStatus.name,
              mode: 'fallback_relaxed',
            );
            continue;
          }
          if (uniqueness.solutionStatus != SolverStatus.unique) {
            nonUniqueCount++;
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptMs,
              outcome: 'rejected',
              rejectReason: 'non_unique',
              solverStatus: uniqueness.solutionStatus.name,
              mode: 'fallback_relaxed',
            );
            continue;
          }

          final Stopwatch difficultyScoreWatch = Stopwatch()..start();
          final DifficultyTelemetry difficultyTelemetry = _difficultyScorer
              .score(
                puzzle: board,
                solution: board,
                context: DifficultyContext(
                  generatorTelemetry: <String, Object?>{
                    'valueCells': altTemplate.valueCellCount,
                    'width': altTemplate.width,
                    'height': altTemplate.height,
                  },
                  solverTelemetry: uniqueness.telemetry,
                ),
              );
          difficultyScoreWatch.stop();
          final String bucket = _difficultyConfig.bucketFor(
            difficultyTelemetry.rawScore,
          );
          final Map<String, Object?> structuralTelemetry = altTemplate
              .buildStructuralTelemetry(entrySums: sol.entrySums);
          puzzle = board;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'accepted',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_relaxed',
          );
          telemetry = <String, Object?>{
            'attempts': attempts + fallbackAttempts,
            'attemptLimit': attemptLimit,
            'generationDurationMs': stopwatch.elapsedMilliseconds,
            'fallback': true,
            'relaxedFallback': true,
            'fallbackMode': 'relaxed',
            'stageTimingMs': <String, int>{
              'layout': layoutWatch.elapsedMilliseconds,
              'layoutScore': layoutScoreMs,
              'fill': attemptMs,
              'clueBuild': 0,
              'uniquenessSolve': 0,
              'difficultyScore': difficultyScoreWatch.elapsedMilliseconds,
              'total': stopwatch.elapsedMilliseconds,
            },
            'measuredDifficultyBucket': bucket,
            'difficultyBucket': bucket,
            'requestedDifficulty': requestedLevel,
            'difficultyMatchedRequest': bucket == requestedLevel,
            'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000)
                .round(),
            'selectedSize': '${altTemplate.width}x${altTemplate.height}',
            'valueCellCount': altTemplate.valueCellCount,
            // Kept for telemetry compatibility; generated starts no longer
            // include digit givens.
            'givensCount': 0,
            'givenRatioMilli': 0,
            'width': altTemplate.width,
            'height': altTemplate.height,
            'layoutScoreMilli': layoutScoreMilli,
            'layoutGateReason': layoutGateReason,
            'layoutGateReasonCounts': layoutGateReasonCounts,
            ...altMetrics.toTelemetry(),
            ...structuralTelemetry,
            'perAttemptBudgetMs': perAttemptBudgetMs,
            'hardBudgetMs': hardTimeBudgetMs,
            'hardCapExceeded': false,
            'attemptsLog': attemptLog,
            'rejectCounters': <String, int>{
              'nullCandidate': nullSolutionCount,
              'layoutGate': layoutGateRejectCount,
              'nonUnique': nonUniqueCount,
              'unknownStatus': unknownStatusCount,
              'logicGate': logicRejectCount,
              'comboGate': comboRejectCount,
              'attemptBudget': attemptBudgetExceededCount,
              'hardBudget': hardBudgetExceededCount,
            },
          };
        }
      }
      if (puzzle == null) {
        throw generationFailure(
          message: 'Unable to generate unique Kakuro within hard budget',
          reason: terminalFailureReason ?? 'attempts_exhausted',
        );
      }
    }

    stopwatch.stop();
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

const Set<int> _supportedKakuroSizes = <int>{5, 7, 9, 11};

int _chooseWidth(GeneratorContext context, String level) {
  return _resolveGridSize(context, level);
}

int _chooseHeight(GeneratorContext context, String level) {
  return _resolveGridSize(context, level);
}

int _resolveGridSize(GeneratorContext context, String level) {
  final int width = context.size.width;
  final int height = context.size.height;
  if (width <= 0 || height <= 0) {
    return _defaultSizeForLevel(level);
  }
  if (width == height && _supportedKakuroSizes.contains(width)) {
    return width;
  }
  throw ArgumentError(
    'Unsupported Kakuro size ${width}x$height for level "$level". '
    'Supported sizes: 5x5, 7x7, 9x9, 11x11.',
  );
}

int _defaultSizeForLevel(String level) {
  switch (level) {
    case 'easy':
      return 7;
    case 'medium':
      return 9;
    case 'hard':
      return 9;
    case 'expert':
      return 9;
    default:
      return 9;
  }
}

int _timeBudgetMillis(String level) {
  switch (level) {
    case 'easy':
      return 3500;
    case 'medium':
      return 4200;
    case 'hard':
      return 5200;
    case 'expert':
      return 8000;
    default:
      return 4200;
  }
}

int _layoutCandidateBudgetFor({
  required int width,
  required int height,
  required String difficulty,
}) {
  if (width == 9 &&
      height == 9 &&
      (difficulty == 'medium' ||
          difficulty == 'hard' ||
          difficulty == 'expert')) {
    return 20;
  }
  return 1;
}

bool _meetsLogicThresholds(String level, Map<String, Object?> telemetry) {
  final int searchNodes =
      (telemetry['searchNodes'] as num?)?.toInt() ??
      (telemetry['backtrackNodes'] as num?)?.toInt() ??
      0;
  final int backtracks = (telemetry['backtracks'] as num?)?.toInt() ?? 0;
  final int maxDepth = (telemetry['maxDepth'] as num?)?.toInt() ?? 0;
  final int maxBranchingFactor =
      (telemetry['maxBranchingFactor'] as num?)?.toInt() ?? 0;
  final double avgRunCombinationCount =
      (telemetry['avgRunCombinationCount'] as num?)?.toDouble() ?? 0.0;
  final double singleComboRunRatio =
      (telemetry['singleComboRunRatio'] as num?)?.toDouble() ?? 0.0;
  final int propagationRounds =
      (telemetry['propagationRounds'] as num?)?.toInt() ?? 0;
  switch (level) {
    case 'easy':
      return searchNodes <= 40 &&
          backtracks <= 24 &&
          maxDepth <= 5 &&
          maxBranchingFactor <= 6 &&
          avgRunCombinationCount <= 3.8 &&
          singleComboRunRatio >= 0.05 &&
          propagationRounds <= 220;
    case 'medium':
      return searchNodes <= 120 &&
          backtracks <= 70 &&
          maxDepth <= 8 &&
          maxBranchingFactor <= 7 &&
          avgRunCombinationCount <= 4.6 &&
          singleComboRunRatio >= 0.02 &&
          propagationRounds <= 320;
    case 'hard':
      return searchNodes <= 260 &&
          backtracks <= 150 &&
          maxDepth <= 12 &&
          maxBranchingFactor <= 8 &&
          avgRunCombinationCount <= 5.8 &&
          propagationRounds <= 520;
    case 'expert':
      return searchNodes <= 640 &&
          backtracks <= 360 &&
          maxDepth <= 16 &&
          maxBranchingFactor <= 9 &&
          avgRunCombinationCount <= 7.5 &&
          propagationRounds <= 900;
    default:
      return searchNodes <= 160;
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
    final Set<int>? combos = KakuroDictionary.getCombinations(
      e.cells.length,
      e.sum,
    );
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
