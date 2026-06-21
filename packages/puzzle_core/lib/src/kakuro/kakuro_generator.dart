library puzzle_core_kakuro_generator;

import 'dart:math' as math;

import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../generators/generator.dart';
import '../generators/kakuro/combos.dart';
import '../generators/kakuro/models.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../util/kakuro_dictionary.dart';
import '../util/seeded_rng.dart';
import 'kakuro_board.dart';
import 'kakuro_difficulty.dart';
import 'kakuro_solver.dart';
import 'kakuro_supported_profiles.dart';

part '../generators/kakuro/layout.dart';
part '../generators/kakuro/layout_family.dart';
part '../generators/kakuro/generator_solution_first.dart';
part '../generators/kakuro/generator_bottom_up.dart';

const int _solverSalt = 0x6f95c2c1ab7342ed;
const int _mixMultiplier = 0x9e3779b97f4a7c15;
const int _mask64 = 0xffffffffffffffff;
const int _maxDeterministicRepairPasses = 2;

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

  // Exposed for tests: deterministic structural candidate selection by attempt.
  static KakuroLayout buildLayoutCandidateForTest({
    required int seed64,
    required int width,
    required int height,
    required String difficulty,
    required int attemptIndex,
  }) {
    return _buildLayoutCandidateForAttempt(
      seed64: seed64,
      width: width,
      height: height,
      difficulty: _normalizeDifficulty(difficulty.trim().toLowerCase()),
      attemptIndex: attemptIndex,
    );
  }

  static Map<String, Object?> scoreConstructionForTest({
    required KakuroLayout template,
    required List<int> values,
    String difficulty = 'medium',
  }) {
    final int cellCount = template.width * template.height;
    if (values.length != cellCount) {
      throw ArgumentError(
        'Expected $cellCount values for ${template.width}x${template.height} layout.',
      );
    }
    final List<int> entryMasks = _entryMasksFromValues(template, values);
    final _KakuroConstructionScorer scorer = _KakuroConstructionScorer(
      template,
    );
    final KakuroConstructionMetrics metrics = scorer.score(entryMasks);
    return <String, Object?>{
      ...metrics.toTelemetry(),
      'constructionScoreMilli': _constructionProfileScoreMilli(
        metrics,
        difficulty,
      ),
    };
  }

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
    int difficultyRejectCount = 0;
    int attemptBudgetExceededCount = 0;
    int hardBudgetExceededCount = 0;
    int repairAttemptCount = 0;
    int repairedRejectCount = 0;
    int repairUniqueLayoutHashCount = 0;
    String repairOutcome = 'not_attempted';
    String repairReason = 'not_attempted';
    bool repairedFromNonUnique = false;
    String finalLayoutHash = 'unknown';
    final Map<String, int> layoutGateReasonCounts = <String, int>{};
    String layoutGateReason = 'not_scored';
    int layoutScoreMilli = 0;
    KakuroLayoutMetrics? selectedLayoutMetrics;
    final List<Map<String, Object?>> acceptedLayoutCandidateTelemetry =
        <Map<String, Object?>>[];
    final List<Map<String, Object?>> rejectedLayoutCandidateTelemetry =
        <Map<String, Object?>>[];
    final List<Map<String, Object?>> attemptLog = <Map<String, Object?>>[];
    Map<String, Object?> telemetry = const <String, Object?>{};
    KakuroBoard? puzzle;
    String? terminalFailureReason;

    // Respect the requested phone-supported size, or use the fixed profile for
    // the requested difficulty when no size is provided.
    final _KakuroGridSize targetSize = _chooseGridSize(context, requestedLevel);
    final int targetWidth = targetSize.width;
    final int targetHeight = targetSize.height;
    final String targetSizeId = '${targetWidth}x$targetHeight';
    final int profileHardTimeBudgetMs = _timeBudgetMillis(requestedLevel);
    final int requestedHardTimeOverrideMs =
        hardTimeLimitOverride?.inMilliseconds ?? profileHardTimeBudgetMs;
    final int hardTimeBudgetMs = _effectiveTimeBudgetMs(requestedLevel);
    final int perAttemptBudgetMs = perAttemptTimeLimit.inMilliseconds;
    final bool allowDifficultyFallback =
        KakuroSupportedProfiles.allowsDifficultyFallback(
          sizeId: targetSizeId,
          difficulty: requestedLevel,
        );
    final Set<String> acceptedDifficultyBuckets = _acceptedDifficultyBuckets(
      requested: requestedLevel,
      allowFallback: allowDifficultyFallback,
    );

    bool overHardBudget() => stopwatch.elapsedMilliseconds >= hardTimeBudgetMs;

    void recordAttempt({
      required int attempt,
      required int durationMs,
      required String outcome,
      String? rejectReason,
      String? solverStatus,
      String? mode,
      Map<String, Object?>? constructionTelemetry,
      int? disagreementCellCount,
      int? disagreementRunCount,
      int? disagreementMaxRunLength,
      int? repairPass,
      String? repairStrategy,
      String? repairOutcome,
      String? repairReason,
      bool? repairedFromNonUnique,
      String? layoutHash,
    }) {
      attemptLog.add(<String, Object?>{
        'attempt': attempt,
        'durationMs': durationMs,
        'outcome': outcome,
        if (rejectReason != null) 'rejectReason': rejectReason,
        if (solverStatus != null) 'solverStatus': solverStatus,
        if (mode != null) 'mode': mode,
        if (disagreementCellCount != null)
          'disagreementCellCount': disagreementCellCount,
        if (disagreementRunCount != null)
          'disagreementRunCount': disagreementRunCount,
        if (disagreementMaxRunLength != null)
          'disagreementMaxRunLength': disagreementMaxRunLength,
        if (repairPass != null) 'repairPass': repairPass,
        if (repairStrategy != null) 'repairStrategy': repairStrategy,
        if (repairOutcome != null) 'repairOutcome': repairOutcome,
        if (repairReason != null) 'repairReason': repairReason,
        if (repairedFromNonUnique != null)
          'repairedFromNonUnique': repairedFromNonUnique,
        if (layoutHash != null) 'layoutHash': layoutHash,
        if (constructionTelemetry != null)
          'constructionTelemetry': constructionTelemetry,
      });
    }

    void recordLayoutCandidate({
      required int candidateIndex,
      required String source,
      required bool accepted,
      required String reason,
      required KakuroLayoutPreScoreResult score,
    }) {
      final Map<String, Object?> entry = <String, Object?>{
        'candidateIndex': candidateIndex,
        'source': source,
        'accepted': accepted,
        'reason': reason,
        'scoreMilli': score.scoreMilli,
        'layoutHash': score.metrics.layoutHash,
        'layoutFamilyId': score.metrics.layoutFamilyId,
        'width': score.metrics.width,
        'height': score.metrics.height,
        'whiteCellCount': score.metrics.whiteCellCount,
        'totalRunCount': score.metrics.totalRunCount,
        'maxRunLength': score.metrics.maxRunLength,
        'averageRunLengthMilli': score.metrics.averageRunLengthMilli,
        'averageRunCombinationEstimateMilli':
            score.metrics.averageRunCombinationEstimateMilli,
        'runLengthWeightedCombinationEstimateMilli':
            score.metrics.runLengthWeightedCombinationEstimateMilli,
        'singleCombinationSumRatioEstimateMilli':
            score.metrics.singleCombinationSumRatioEstimateMilli,
      };
      if (accepted) {
        acceptedLayoutCandidateTelemetry.add(entry);
      } else {
        rejectedLayoutCandidateTelemetry.add(entry);
      }
    }

    Map<String, int> buildRejectCounters() {
      return <String, int>{
        'nullCandidate': nullSolutionCount,
        'layoutGate': layoutGateRejectCount,
        'nonUnique': nonUniqueCount,
        'unknownStatus': unknownStatusCount,
        'logicGate': logicRejectCount,
        'comboGate': comboRejectCount,
        'difficultyGate': difficultyRejectCount,
        'attemptBudget': attemptBudgetExceededCount,
        'hardBudget': hardBudgetExceededCount,
        'repairRejected': repairedRejectCount,
      };
    }

    Map<String, Object?> buildLayoutCandidateTelemetry() {
      return <String, Object?>{
        'layoutCandidateCount':
            acceptedLayoutCandidateTelemetry.length +
            rejectedLayoutCandidateTelemetry.length,
        'acceptedLayoutCandidateCount': acceptedLayoutCandidateTelemetry.length,
        'rejectedLayoutCandidateCount': rejectedLayoutCandidateTelemetry.length,
        'acceptedLayoutCandidates': acceptedLayoutCandidateTelemetry,
        'rejectedLayoutCandidates': rejectedLayoutCandidateTelemetry,
      };
    }

    final Stopwatch layoutWatch = Stopwatch()..start();
    final Stopwatch layoutScoreWatch = Stopwatch();
    final int maxLayoutCandidates = _layoutCandidateBudgetFor(
      width: targetWidth,
      height: targetHeight,
      difficulty: requestedLevel,
    );
    final Set<String> acceptedLayoutHashes = <String>{};
    final List<_KakuroAcceptedLayoutCandidate> acceptedLayouts =
        <_KakuroAcceptedLayoutCandidate>[];
    int bestAcceptedLayoutScore = -1;
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
      final KakuroLayout candidate = _buildLayoutCandidateForAttempt(
        seed64: context.seed64,
        width: targetWidth,
        height: targetHeight,
        difficulty: requestedLevel,
        attemptIndex: candidateIndex,
        newspaperRng: context.rng,
      );
      layoutScoreWatch.start();
      final KakuroLayoutPreScoreResult preScore = layoutPreScorer.score(
        layout: candidate,
        difficulty: requestedLevel,
      );
      layoutScoreWatch.stop();
      if (preScore.accepted) {
        if (!acceptedLayoutHashes.add(preScore.metrics.layoutHash)) {
          layoutGateRejectCount++;
          layoutGateReason = 'duplicate_layout_candidate';
          layoutGateReasonCounts['duplicate_layout_candidate'] =
              (layoutGateReasonCounts['duplicate_layout_candidate'] ?? 0) + 1;
          recordLayoutCandidate(
            candidateIndex: candidateIndex,
            source: 'initial',
            accepted: false,
            reason: 'duplicate_layout_candidate',
            score: preScore,
          );
          continue;
        }
        recordLayoutCandidate(
          candidateIndex: candidateIndex,
          source: 'initial',
          accepted: true,
          reason: preScore.reason,
          score: preScore,
        );
        acceptedLayouts.add(
          _KakuroAcceptedLayoutCandidate(
            layout: candidate,
            scoreMilli: preScore.scoreMilli,
            reason: preScore.reason,
            metrics: preScore.metrics,
          ),
        );
        bestAcceptedLayoutScore = math.max(
          bestAcceptedLayoutScore,
          preScore.scoreMilli,
        );
        if (preScore.scoreMilli >=
            _layoutEarlyAcceptScoreThreshold(
              width: targetWidth,
              height: targetHeight,
              difficulty: requestedLevel,
            )) {
          break;
        }
        continue;
      }
      layoutGateRejectCount++;
      layoutGateReason = preScore.reason;
      layoutGateReasonCounts[preScore.reason] =
          (layoutGateReasonCounts[preScore.reason] ?? 0) + 1;
      recordLayoutCandidate(
        candidateIndex: candidateIndex,
        source: 'initial',
        accepted: false,
        reason: preScore.reason,
        score: preScore,
      );
    }
    layoutWatch.stop();
    final int layoutScoreMs = layoutScoreWatch.elapsedMilliseconds;
    if (acceptedLayouts.isEmpty) {
      terminalFailureReason ??= 'layout_gate_exhausted';
    } else {
      acceptedLayouts.sort(
        (_KakuroAcceptedLayoutCandidate a, _KakuroAcceptedLayoutCandidate b) =>
            _compareAcceptedLayoutCandidates(a, b),
      );
      final _KakuroAcceptedLayoutCandidate top = acceptedLayouts.first;
      layoutScoreMilli = top.scoreMilli;
      layoutGateReason = top.reason;
      selectedLayoutMetrics = top.metrics;
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
          'profileHardBudgetMs': profileHardTimeBudgetMs,
          'requestedHardBudgetOverrideMs': requestedHardTimeOverrideMs,
          'perAttemptBudgetMs': perAttemptBudgetMs,
          'rejectCounters': buildRejectCounters(),
          'layoutScoreMilli': layoutScoreMilli,
          'layoutGateReason': layoutGateReason,
          'layoutGateReasonCounts': layoutGateReasonCounts,
          'bestAcceptedLayoutScoreMilli': bestAcceptedLayoutScore,
          ...buildLayoutCandidateTelemetry(),
          'repairAttemptCount': repairAttemptCount,
          'repairOutcome': repairOutcome,
          'repairReason': repairReason,
          'repairedFromNonUnique': repairedFromNonUnique,
          'difficultyAcceptedBuckets': acceptedDifficultyBuckets.toList(),
          'allowDifficultyFallback': allowDifficultyFallback,
          'repairUniqueLayoutHashCount': repairUniqueLayoutHashCount,
          'finalLayoutHash': finalLayoutHash,
          'attemptsLog': attemptLog,
        },
      );
    }

    if (acceptedLayouts.isEmpty) {
      throw generationFailure(
        message: 'Unable to find Kakuro layout passing pre-score gate',
        reason: terminalFailureReason ?? 'layout_gate_exhausted',
      );
    }

    _KakuroAcceptedRepairCandidate? tryRepairNonUnique({
      required int attemptNumber,
      required String mode,
      required KakuroLayout template,
      required SolverResult<KakuroBoard> nonUniqueResult,
      required Stopwatch attemptWatch,
    }) {
      if (nonUniqueResult.solutionStatus != SolverStatus.multiple) {
        return null;
      }
      final _KakuroDisagreementFocus? focus =
          _KakuroDisagreementFocus.fromSummary(
            nonUniqueResult.telemetry['disagreementSummary'],
          );
      if (focus == null) {
        repairOutcome = 'rejected';
        repairReason = 'disagreement_summary_missing';
        return null;
      }

      final int focusSeed = _repairFocusSeed(focus);
      final int repairSeedBase =
          context.seed64 ^
          focusSeed ^
          Seed.fromString('kakuro_repair:$mode:$requestedLevel');
      String lastReason = 'repair_exhausted';
      bool attemptedRepair = false;
      final Set<String> seenRepairedLayoutHashes = <String>{};
      final Set<String> seenNonUniqueSignatures = <String>{};

      for (int pass = 0; pass < _maxDeterministicRepairPasses; pass++) {
        if (overHardBudget()) {
          lastReason = 'hard_budget_exceeded';
          break;
        }
        if (attemptWatch.elapsedMilliseconds > perAttemptBudgetMs) {
          lastReason = 'attempt_budget_exceeded_before_repair';
          break;
        }
        attemptedRepair = true;
        repairAttemptCount++;

        final bool useLayoutMutation = pass.isOdd;
        final String strategy = useLayoutMutation
            ? 'local_layout_mutation'
            : 'implicated_refill';

        KakuroLayout repairedLayout = template;
        if (useLayoutMutation) {
          final KakuroLayout? mutated = _mutateLayoutAroundImplicatedRegion(
            template: template,
            focus: focus,
          );
          if (mutated == null) {
            lastReason = 'layout_mutation_invalid';
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptWatch.elapsedMilliseconds,
              outcome: 'rejected',
              rejectReason: 'repair_mutation_invalid',
              solverStatus: SolverStatus.multiple.name,
              mode: '${mode}_repair',
              repairPass: pass + 1,
              repairStrategy: strategy,
              repairOutcome: 'rejected',
              repairReason: lastReason,
              repairedFromNonUnique: false,
              layoutHash: _computeLayoutHash(template.layout),
            );
            continue;
          }
          repairedLayout = mutated;
        }
        final String repairedLayoutHash = _computeLayoutHash(
          repairedLayout.layout,
        );
        if (!seenRepairedLayoutHashes.add(repairedLayoutHash)) {
          lastReason = 'repair_duplicate_layout';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'repair_duplicate_layout',
            solverStatus: SolverStatus.multiple.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
          );
          continue;
        }
        repairUniqueLayoutHashCount++;

        final List<KakuroSolution> fillCandidates = <KakuroSolution>[];
        for (int variant = 0; variant < 2; variant++) {
          final int solveAttempt = attemptNumber + (pass * 16) + variant + 1;
          final int stageBase = 5000 + (pass * 40) + (variant * 4);
          KakuroSolution? variantSolution = buildSolutionFirst(
            repairedLayout,
            SeededRng(
              _deriveSolverSeed(repairSeedBase, solveAttempt, stageBase + 1),
            ),
            difficulty: requestedLevel,
          );
          if (variantSolution != null) {
            fillCandidates.add(variantSolution);
          }
        }

        if (fillCandidates.isEmpty) {
          lastReason = 'repair_refill_failed';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'repair_refill_failed',
            solverStatus: SolverStatus.noSolution.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
          );
          continue;
        }

        KakuroSolution selectedSolution = fillCandidates.first;
        int selectedStrength = _scoreImplicatedRunStrength(
          layout: repairedLayout,
          entrySums: selectedSolution.entrySums,
          focus: focus,
        );
        for (int idx = 1; idx < fillCandidates.length; idx++) {
          final KakuroSolution candidate = fillCandidates[idx];
          final int strength = _scoreImplicatedRunStrength(
            layout: repairedLayout,
            entrySums: candidate.entrySums,
            focus: focus,
          );
          if (strength > selectedStrength ||
              (strength == selectedStrength &&
                  candidate.constructionScoreMilli >
                      selectedSolution.constructionScoreMilli)) {
            selectedSolution = candidate;
            selectedStrength = strength;
          }
        }

        final Stopwatch clueBuildWatch = Stopwatch()..start();
        final KakuroBoard board = repairedLayout.buildBoard(
          selectedSolution.entrySums,
        );
        clueBuildWatch.stop();

        final Stopwatch uniquenessSolveWatch = Stopwatch()..start();
        SolverResult<KakuroBoard> uniqueness = strictSolver.solve(
          board,
          SolverContext(
            rng: SeededRng(
              _deriveSolverSeed(
                repairSeedBase,
                attemptNumber + (pass * 32) + 1,
                7001,
              ),
            ),
            maxSolutions: 2,
          ),
        );
        if (uniqueness.solutionStatus == SolverStatus.unknown) {
          uniqueness = exhaustiveFallbackSolver.solve(
            board,
            SolverContext(
              rng: SeededRng(
                _deriveSolverSeed(
                  repairSeedBase,
                  attemptNumber + (pass * 32) + 1,
                  7002,
                ),
              ),
              maxSolutions: 2,
            ),
          );
        }
        uniquenessSolveWatch.stop();

        final Stopwatch difficultyScoreWatch = Stopwatch()..start();
        final DifficultyTelemetry difficultyTelemetry = _difficultyScorer.score(
          puzzle: board,
          solution: board,
          context: DifficultyContext(
            generatorTelemetry: <String, Object?>{
              'givens': 0,
              'valueCells': repairedLayout.valueCellCount,
              'width': repairedLayout.width,
              'height': repairedLayout.height,
            },
            solverTelemetry: uniqueness.telemetry,
          ),
        );
        difficultyScoreWatch.stop();
        final Map<String, Object?> repairConstructionTelemetry =
            <String, Object?>{
              ...selectedSolution.constructionTelemetry(),
              'repairDifficultyScoreMilli':
                  (difficultyTelemetry.rawScore * 1000).round(),
            };

        if (overHardBudget()) {
          lastReason = 'hard_budget_exceeded';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'hard_budget_exceeded',
            solverStatus: uniqueness.solutionStatus.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
            constructionTelemetry: repairConstructionTelemetry,
          );
          break;
        }
        if (attemptWatch.elapsedMilliseconds > perAttemptBudgetMs) {
          lastReason = 'attempt_budget_exceeded_after_repair';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'attempt_budget_exceeded_after_repair',
            solverStatus: uniqueness.solutionStatus.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
            constructionTelemetry: repairConstructionTelemetry,
          );
          continue;
        }

        if (uniqueness.solutionStatus == SolverStatus.unknown) {
          lastReason = 'solver_status_unknown';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'solver_status_unknown',
            solverStatus: uniqueness.solutionStatus.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
            constructionTelemetry: repairConstructionTelemetry,
          );
          continue;
        }
        if (uniqueness.solutionStatus != SolverStatus.unique) {
          final String nonUniqueSignature = _buildNonUniqueSignature(
            layoutHash: repairedLayoutHash,
            telemetry: uniqueness.telemetry,
          );
          if (!seenNonUniqueSignatures.add(nonUniqueSignature)) {
            lastReason = 'repair_repeated_non_unique';
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptWatch.elapsedMilliseconds,
              outcome: 'rejected',
              rejectReason: 'repair_repeated_non_unique',
              solverStatus: uniqueness.solutionStatus.name,
              mode: '${mode}_repair',
              repairPass: pass + 1,
              repairStrategy: strategy,
              repairOutcome: 'rejected',
              repairReason: lastReason,
              repairedFromNonUnique: false,
              layoutHash: repairedLayoutHash,
              constructionTelemetry: repairConstructionTelemetry,
            );
            break;
          }
          lastReason = 'non_unique';
          final Map<String, int>? disagreementMetrics =
              _nonUniqueDisagreementMetrics(uniqueness.telemetry);
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'non_unique',
            solverStatus: uniqueness.solutionStatus.name,
            mode: '${mode}_repair',
            disagreementCellCount:
                disagreementMetrics?['disagreementCellCount'],
            disagreementRunCount: disagreementMetrics?['disagreementRunCount'],
            disagreementMaxRunLength:
                disagreementMetrics?['disagreementMaxRunLength'],
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
            constructionTelemetry: repairConstructionTelemetry,
          );
          continue;
        }
        if (!_meetsLogicThresholds(requestedLevel, uniqueness.telemetry)) {
          lastReason = 'logic_gate';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'logic_gate',
            solverStatus: uniqueness.solutionStatus.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
            constructionTelemetry: repairConstructionTelemetry,
          );
          continue;
        }
        if (!_meetsSingleComboThreshold(
          repairedLayout,
          board,
          requestedLevel,
        )) {
          lastReason = 'combo_gate';
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'combo_gate',
            solverStatus: uniqueness.solutionStatus.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: lastReason,
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
            constructionTelemetry: repairConstructionTelemetry,
          );
          continue;
        }
        final String measuredBucket = _difficultyConfig.bucketFor(
          difficultyTelemetry.rawScore,
        );
        if (!acceptedDifficultyBuckets.contains(measuredBucket)) {
          lastReason = 'difficulty_gate';
          difficultyRejectCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptWatch.elapsedMilliseconds,
            outcome: 'rejected',
            rejectReason: 'difficulty_gate',
            solverStatus: uniqueness.solutionStatus.name,
            mode: '${mode}_repair',
            repairPass: pass + 1,
            repairStrategy: strategy,
            repairOutcome: 'rejected',
            repairReason: '$lastReason:$measuredBucket',
            repairedFromNonUnique: false,
            layoutHash: repairedLayoutHash,
            constructionTelemetry: <String, Object?>{
              ...repairConstructionTelemetry,
              'measuredDifficultyBucket': measuredBucket,
              'acceptedDifficultyBuckets': acceptedDifficultyBuckets.toList(),
            },
          );
          continue;
        }

        repairOutcome = 'accepted';
        repairReason = 'accepted_$strategy';
        repairedFromNonUnique = true;
        finalLayoutHash = repairedLayoutHash;
        recordAttempt(
          attempt: attemptNumber,
          durationMs: attemptWatch.elapsedMilliseconds,
          outcome: 'accepted',
          solverStatus: uniqueness.solutionStatus.name,
          mode: '${mode}_repair',
          repairPass: pass + 1,
          repairStrategy: strategy,
          repairOutcome: 'accepted',
          repairReason: repairReason,
          repairedFromNonUnique: true,
          layoutHash: finalLayoutHash,
          constructionTelemetry: repairConstructionTelemetry,
        );
        return _KakuroAcceptedRepairCandidate(
          layout: repairedLayout,
          solution: selectedSolution,
          board: board,
          uniqueness: uniqueness,
        );
      }

      if (attemptedRepair) {
        repairedRejectCount++;
      }
      repairOutcome = attemptedRepair ? 'rejected' : repairOutcome;
      repairReason = lastReason;
      return null;
    }

    while (attempts < attemptLimit) {
      if (overHardBudget()) {
        hardBudgetExceededCount++;
        terminalFailureReason = 'hard_budget_exceeded';
        break;
      }
      attempts++;
      final Stopwatch attemptWatch = Stopwatch()..start();
      final _KakuroAcceptedLayoutCandidate templateCandidate =
          acceptedLayouts[(attempts - 1) % acceptedLayouts.length];
      KakuroLayout selectedTemplate = templateCandidate.layout;
      KakuroLayoutMetrics selectedMetrics = templateCandidate.metrics;
      layoutScoreMilli = templateCandidate.scoreMilli;
      layoutGateReason = templateCandidate.reason;
      selectedLayoutMetrics = selectedMetrics;
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
        difficulty: requestedLevel,
      );
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
      Map<String, Object?> constructionTelemetry = solution
          .constructionTelemetry();

      if (attemptWatch.elapsedMilliseconds > perAttemptBudgetMs) {
        attemptBudgetExceededCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptWatch.elapsedMilliseconds,
          outcome: 'rejected',
          rejectReason: 'attempt_budget_exceeded_after_candidate',
          mode: 'primary',
          constructionTelemetry: constructionTelemetry,
        );
        continue;
      }

      final Stopwatch clueBuildWatch = Stopwatch()..start();
      // Production Kakuro starts with empty playable cells. Uniqueness must
      // come from layout and clue constraints, not hidden answer givens.
      KakuroBoard candidateBoard = selectedTemplate.buildBoard(
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

      int attemptMs = attemptWatch.elapsedMilliseconds;
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
          constructionTelemetry: constructionTelemetry,
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
          constructionTelemetry: constructionTelemetry,
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
          constructionTelemetry: constructionTelemetry,
        );
        continue;
      }
      if (uniqueness.solutionStatus != SolverStatus.unique) {
        _KakuroAcceptedRepairCandidate? repaired;
        if (uniqueness.solutionStatus == SolverStatus.multiple &&
            uniqueness.telemetry['disagreementSummary'] != null) {
          repaired = tryRepairNonUnique(
            attemptNumber: attempts,
            mode: 'primary',
            template: selectedTemplate,
            nonUniqueResult: uniqueness,
            attemptWatch: attemptWatch,
          );
        }
        if (repaired == null) {
          nonUniqueCount++;
          final Map<String, int>? disagreementMetrics =
              _nonUniqueDisagreementMetrics(uniqueness.telemetry);
          recordAttempt(
            attempt: attempts,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'non_unique',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'primary',
            disagreementCellCount:
                disagreementMetrics?['disagreementCellCount'],
            disagreementRunCount: disagreementMetrics?['disagreementRunCount'],
            disagreementMaxRunLength:
                disagreementMetrics?['disagreementMaxRunLength'],
            repairOutcome: uniqueness.solutionStatus == SolverStatus.multiple
                ? repairOutcome
                : null,
            repairReason: uniqueness.solutionStatus == SolverStatus.multiple
                ? repairReason
                : null,
            repairedFromNonUnique: false,
            layoutHash: _computeLayoutHash(selectedTemplate.layout),
            constructionTelemetry: constructionTelemetry,
          );
          continue;
        }
        selectedTemplate = repaired.layout;
        selectedMetrics = selectedTemplate.computeMetrics();
        selectedLayoutMetrics = selectedMetrics;
        solution = repaired.solution;
        candidateBoard = repaired.board;
        uniqueness = repaired.uniqueness;
        constructionTelemetry = repaired.solution.constructionTelemetry();
        attemptMs = attemptWatch.elapsedMilliseconds;
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
          constructionTelemetry: constructionTelemetry,
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
          constructionTelemetry: constructionTelemetry,
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
      if (!acceptedDifficultyBuckets.contains(bucket)) {
        difficultyRejectCount++;
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'rejected',
          rejectReason: 'difficulty_gate',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
          constructionTelemetry: <String, Object?>{
            ...constructionTelemetry,
            'measuredDifficultyBucket': bucket,
            'acceptedDifficultyBuckets': acceptedDifficultyBuckets.toList(),
          },
        );
        continue;
      }

      final Map<String, Object?> sanitizedSolverTelemetry = uniqueness.telemetry
          .map((String key, Object? value) {
            if (value is double) {
              return MapEntry<String, Object?>(key, (value * 1000).round());
            }
            return MapEntry<String, Object?>(key, value);
          });

      if (!repairedFromNonUnique) {
        if (repairAttemptCount == 0) {
          repairOutcome = 'not_needed';
          repairReason = 'not_needed';
        } else if (repairOutcome != 'accepted') {
          repairOutcome = 'rejected_before_accept';
          if (repairReason == 'not_attempted') {
            repairReason = 'repair_rejected_before_accept';
          }
        }
      }
      finalLayoutHash = selectedMetrics.layoutHash;

      puzzle = candidateBoard;
      if (!repairedFromNonUnique) {
        recordAttempt(
          attempt: attempts,
          durationMs: attemptMs,
          outcome: 'accepted',
          solverStatus: uniqueness.solutionStatus.name,
          mode: 'primary',
          repairOutcome: repairOutcome,
          repairReason: repairReason,
          repairedFromNonUnique: repairedFromNonUnique,
          layoutHash: finalLayoutHash,
          constructionTelemetry: constructionTelemetry,
        );
      }
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
        'constructionTelemetry': constructionTelemetry,
        'solverTelemetry': sanitizedSolverTelemetry,
        'measuredDifficultyBucket': bucket,
        'difficultyBucket': bucket,
        'requestedDifficulty': requestedLevel,
        'difficultyMatchedRequest': bucket == requestedLevel,
        'difficultyAcceptedBuckets': acceptedDifficultyBuckets.toList(),
        'allowDifficultyFallback': allowDifficultyFallback,
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
        'bestAcceptedLayoutScoreMilli': bestAcceptedLayoutScore,
        ...buildLayoutCandidateTelemetry(),
        ...selectedLayoutMetrics.toTelemetry(),
        ...structuralTelemetry,
        'repairAttemptCount': repairAttemptCount,
        'repairOutcome': repairOutcome,
        'repairReason': repairReason,
        'repairedFromNonUnique': repairedFromNonUnique,
        'repairedRejectCount': repairedRejectCount,
        'acceptPath': repairedFromNonUnique ? 'repaired' : 'primary',
        'finalLayoutHash': finalLayoutHash,
        'perAttemptBudgetMs': perAttemptBudgetMs,
        'hardBudgetMs': hardTimeBudgetMs,
        'profileHardBudgetMs': profileHardTimeBudgetMs,
        'requestedHardBudgetOverrideMs': requestedHardTimeOverrideMs,
        'hardCapExceeded': false,
        'attemptsLog': attemptLog,
        'repairUniqueLayoutHashCount': repairUniqueLayoutHashCount,
        'rejectCounters': buildRejectCounters(),
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
        final KakuroLayout altTemplate = _buildLayoutCandidateForAttempt(
          seed64: context.seed64,
          width: targetWidth,
          height: targetHeight,
          difficulty: requestedLevel,
          attemptIndex: maxLayoutCandidates + alt,
          newspaperRng: SeededRng(
            _deriveSolverSeed(context.seed64, 1234, alt + 1),
          ),
        );
        final KakuroLayoutPreScoreResult preScore = layoutPreScorer.score(
          layout: altTemplate,
          difficulty: requestedLevel,
        );
        layoutScoreMilli = preScore.scoreMilli;
        layoutGateReason = preScore.reason;
        recordLayoutCandidate(
          candidateIndex: maxLayoutCandidates + alt,
          source: 'fallback_strict',
          accepted: preScore.accepted,
          reason: preScore.reason,
          score: preScore,
        );
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
        KakuroLayoutMetrics altMetrics = preScore.metrics;
        KakuroLayout workingTemplate = altTemplate;
        KakuroSolution? sol = buildSolutionFirst(
          workingTemplate,
          SeededRng(_deriveSolverSeed(context.seed64, 2234, alt + 1)),
          difficulty: requestedLevel,
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
        Map<String, Object?> constructionTelemetry = sol
            .constructionTelemetry();
        KakuroBoard board = workingTemplate.buildBoard(sol.entrySums);
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
        int attemptMs = attemptWatch.elapsedMilliseconds;
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
            constructionTelemetry: constructionTelemetry,
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
            constructionTelemetry: constructionTelemetry,
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
            constructionTelemetry: constructionTelemetry,
          );
          continue;
        }
        if (uniqueness.solutionStatus != SolverStatus.unique) {
          _KakuroAcceptedRepairCandidate? repaired;
          if (uniqueness.solutionStatus == SolverStatus.multiple &&
              uniqueness.telemetry['disagreementSummary'] != null) {
            repaired = tryRepairNonUnique(
              attemptNumber: attemptNumber,
              mode: 'fallback_strict',
              template: workingTemplate,
              nonUniqueResult: uniqueness,
              attemptWatch: attemptWatch,
            );
          }
          if (repaired == null) {
            nonUniqueCount++;
            final Map<String, int>? disagreementMetrics =
                _nonUniqueDisagreementMetrics(uniqueness.telemetry);
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptMs,
              outcome: 'rejected',
              rejectReason: 'non_unique',
              solverStatus: uniqueness.solutionStatus.name,
              mode: 'fallback_strict',
              disagreementCellCount:
                  disagreementMetrics?['disagreementCellCount'],
              disagreementRunCount:
                  disagreementMetrics?['disagreementRunCount'],
              disagreementMaxRunLength:
                  disagreementMetrics?['disagreementMaxRunLength'],
              repairOutcome: uniqueness.solutionStatus == SolverStatus.multiple
                  ? repairOutcome
                  : null,
              repairReason: uniqueness.solutionStatus == SolverStatus.multiple
                  ? repairReason
                  : null,
              repairedFromNonUnique: false,
              layoutHash: _computeLayoutHash(workingTemplate.layout),
              constructionTelemetry: constructionTelemetry,
            );
            continue;
          }
          workingTemplate = repaired.layout;
          altMetrics = workingTemplate.computeMetrics();
          sol = repaired.solution;
          board = repaired.board;
          uniqueness = repaired.uniqueness;
          constructionTelemetry = sol.constructionTelemetry();
          attemptMs = attemptWatch.elapsedMilliseconds;
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
            constructionTelemetry: constructionTelemetry,
          );
          continue;
        }
        if (!_meetsSingleComboThreshold(
          workingTemplate,
          board,
          requestedLevel,
        )) {
          comboRejectCount++;
          recordAttempt(
            attempt: attemptNumber,
            durationMs: attemptMs,
            outcome: 'rejected',
            rejectReason: 'combo_gate',
            solverStatus: uniqueness.solutionStatus.name,
            mode: 'fallback_strict',
            constructionTelemetry: constructionTelemetry,
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
                    'valueCells': workingTemplate.valueCellCount,
                    'width': workingTemplate.width,
                    'height': workingTemplate.height,
                  },
                  solverTelemetry: uniqueness.telemetry,
                ),
              );
          difficultyScoreWatch.stop();
          final String bucket = _difficultyConfig.bucketFor(
            difficultyTelemetry.rawScore,
          );
          final Map<String, Object?> structuralTelemetry = workingTemplate
              .buildStructuralTelemetry(entrySums: sol.entrySums);
          if (!acceptedDifficultyBuckets.contains(bucket)) {
            difficultyRejectCount++;
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptMs,
              outcome: 'rejected',
              rejectReason: 'difficulty_gate',
              solverStatus: uniqueness.solutionStatus.name,
              mode: 'fallback_strict',
              constructionTelemetry: <String, Object?>{
                ...constructionTelemetry,
                'measuredDifficultyBucket': bucket,
                'acceptedDifficultyBuckets': acceptedDifficultyBuckets.toList(),
              },
            );
            continue;
          }
          if (!repairedFromNonUnique) {
            if (repairAttemptCount == 0) {
              repairOutcome = 'not_needed';
              repairReason = 'not_needed';
            } else if (repairOutcome != 'accepted') {
              repairOutcome = 'rejected_before_accept';
              if (repairReason == 'not_attempted') {
                repairReason = 'repair_rejected_before_accept';
              }
            }
          }
          finalLayoutHash = altMetrics.layoutHash;
          puzzle = board;
          if (!repairedFromNonUnique) {
            recordAttempt(
              attempt: attemptNumber,
              durationMs: attemptMs,
              outcome: 'accepted',
              solverStatus: uniqueness.solutionStatus.name,
              mode: 'fallback_strict',
              repairOutcome: repairOutcome,
              repairReason: repairReason,
              repairedFromNonUnique: repairedFromNonUnique,
              layoutHash: finalLayoutHash,
              constructionTelemetry: constructionTelemetry,
            );
          }
          telemetry = <String, Object?>{
            'attempts': attempts + fallbackAttempts,
            'attemptLimit': attemptLimit,
            'generationDurationMs': stopwatch.elapsedMilliseconds,
            'fallback': true,
            'fallbackMode': 'strict',
            'constructionTelemetry': constructionTelemetry,
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
            'difficultyAcceptedBuckets': acceptedDifficultyBuckets.toList(),
            'allowDifficultyFallback': allowDifficultyFallback,
            'difficultyScoreMilli': (difficultyTelemetry.rawScore * 1000)
                .round(),
            'selectedSize':
                '${workingTemplate.width}x${workingTemplate.height}',
            'valueCellCount': workingTemplate.valueCellCount,
            // Kept for telemetry compatibility; generated starts no longer
            // include digit givens.
            'givensCount': 0,
            'givenRatioMilli': 0,
            'width': workingTemplate.width,
            'height': workingTemplate.height,
            'layoutScoreMilli': layoutScoreMilli,
            'layoutGateReason': layoutGateReason,
            'layoutGateReasonCounts': layoutGateReasonCounts,
            'bestAcceptedLayoutScoreMilli': bestAcceptedLayoutScore,
            ...buildLayoutCandidateTelemetry(),
            ...altMetrics.toTelemetry(),
            ...structuralTelemetry,
            'repairAttemptCount': repairAttemptCount,
            'repairOutcome': repairOutcome,
            'repairReason': repairReason,
            'repairedFromNonUnique': repairedFromNonUnique,
            'repairedRejectCount': repairedRejectCount,
            'acceptPath': repairedFromNonUnique ? 'repaired' : 'primary',
            'finalLayoutHash': finalLayoutHash,
            'perAttemptBudgetMs': perAttemptBudgetMs,
            'hardBudgetMs': hardTimeBudgetMs,
            'profileHardBudgetMs': profileHardTimeBudgetMs,
            'requestedHardBudgetOverrideMs': requestedHardTimeOverrideMs,
            'hardCapExceeded': false,
            'attemptsLog': attemptLog,
            'repairUniqueLayoutHashCount': repairUniqueLayoutHashCount,
            'rejectCounters': buildRejectCounters(),
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
    if (hardTimeLimitOverride != null &&
        hardTimeLimitOverride!.inMilliseconds > 0) {
      return hardTimeLimitOverride!.inMilliseconds;
    }
    return base;
  }
}

class _KakuroAcceptedLayoutCandidate {
  const _KakuroAcceptedLayoutCandidate({
    required this.layout,
    required this.scoreMilli,
    required this.reason,
    required this.metrics,
  });

  final KakuroLayout layout;
  final int scoreMilli;
  final String reason;
  final KakuroLayoutMetrics metrics;
}

int _compareAcceptedLayoutCandidates(
  _KakuroAcceptedLayoutCandidate a,
  _KakuroAcceptedLayoutCandidate b,
) {
  int cmp = b.scoreMilli.compareTo(a.scoreMilli);
  if (cmp != 0) {
    return cmp;
  }
  cmp = b.metrics.totalRunCount.compareTo(a.metrics.totalRunCount);
  if (cmp != 0) {
    return cmp;
  }
  cmp = a.metrics.averageRunCombinationEstimateMilli.compareTo(
    b.metrics.averageRunCombinationEstimateMilli,
  );
  if (cmp != 0) {
    return cmp;
  }
  cmp = a.metrics.runLengthWeightedCombinationEstimateMilli.compareTo(
    b.metrics.runLengthWeightedCombinationEstimateMilli,
  );
  if (cmp != 0) {
    return cmp;
  }
  cmp = a.metrics.maxRunLength.compareTo(b.metrics.maxRunLength);
  if (cmp != 0) {
    return cmp;
  }
  return a.metrics.layoutHash.compareTo(b.metrics.layoutHash);
}

class _KakuroAcceptedRepairCandidate {
  const _KakuroAcceptedRepairCandidate({
    required this.layout,
    required this.solution,
    required this.board,
    required this.uniqueness,
  });

  final KakuroLayout layout;
  final KakuroSolution solution;
  final KakuroBoard board;
  final SolverResult<KakuroBoard> uniqueness;
}

class _KakuroDisagreementFocus {
  const _KakuroDisagreementFocus({
    required this.acrossRunIds,
    required this.downRunIds,
    required this.minRow,
    required this.maxRow,
    required this.minCol,
    required this.maxCol,
  });

  final List<int> acrossRunIds;
  final List<int> downRunIds;
  final int minRow;
  final int maxRow;
  final int minCol;
  final int maxCol;

  bool get hasBoundingBox =>
      minRow >= 0 && minCol >= 0 && maxRow >= minRow && maxCol >= minCol;

  int get centerRow => hasBoundingBox ? (minRow + maxRow) ~/ 2 : -1;
  int get centerCol => hasBoundingBox ? (minCol + maxCol) ~/ 2 : -1;

  Set<int> get runIds => <int>{...acrossRunIds, ...downRunIds};

  static _KakuroDisagreementFocus? fromSummary(Object? summaryRaw) {
    if (summaryRaw is! Map) {
      return null;
    }
    final Map<String, Object?> summary = Map<String, Object?>.from(summaryRaw);
    final Map<String, Object?> runIds = _asObjectMap(
      summary['disagreementRunIds'],
    );
    final List<int> across = _asSortedIntList(runIds['across']);
    final List<int> down = _asSortedIntList(runIds['down']);
    final Map<String, Object?> box = _asObjectMap(
      summary['disagreementBoundingBox'],
    );
    final int minRow = (box['minRow'] as num?)?.toInt() ?? -1;
    final int maxRow = (box['maxRow'] as num?)?.toInt() ?? -1;
    final int minCol = (box['minCol'] as num?)?.toInt() ?? -1;
    final int maxCol = (box['maxCol'] as num?)?.toInt() ?? -1;
    if (across.isEmpty && down.isEmpty) {
      return null;
    }
    return _KakuroDisagreementFocus(
      acrossRunIds: across,
      downRunIds: down,
      minRow: minRow,
      maxRow: maxRow,
      minCol: minCol,
      maxCol: maxCol,
    );
  }
}

Map<String, Object?> _asObjectMap(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return const <String, Object?>{};
}

List<int> _asSortedIntList(Object? value) {
  if (value is! List) {
    return const <int>[];
  }
  final List<int> ints =
      value
          .where((Object? item) => item is num)
          .map((Object? item) => (item as num).toInt())
          .toSet()
          .toList(growable: false)
        ..sort();
  return ints;
}

int _repairFocusSeed(_KakuroDisagreementFocus focus) {
  int hash = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;
  for (final int runId in focus.acrossRunIds) {
    hash ^= runId;
    hash = (hash * prime) & _mask64;
  }
  hash ^= 0x41;
  hash = (hash * prime) & _mask64;
  for (final int runId in focus.downRunIds) {
    hash ^= runId;
    hash = (hash * prime) & _mask64;
  }
  hash ^= focus.minRow;
  hash = (hash * prime) & _mask64;
  hash ^= focus.maxRow;
  hash = (hash * prime) & _mask64;
  hash ^= focus.minCol;
  hash = (hash * prime) & _mask64;
  hash ^= focus.maxCol;
  hash = (hash * prime) & _mask64;
  return hash & _mask64;
}

int _scoreImplicatedRunStrength({
  required KakuroLayout layout,
  required Map<int, int> entrySums,
  required _KakuroDisagreementFocus focus,
}) {
  int singleCount = 0;
  int totalComboCount = 0;
  int maxComboCount = 0;
  int considered = 0;
  for (final int runId in focus.runIds) {
    if (runId < 0 || runId >= layout.entries.length) {
      continue;
    }
    final KakuroLayoutEntry entry = layout.entries[runId];
    final int sum = entrySums[runId] ?? 0;
    final Set<int>? combos = KakuroDictionary.getCombinations(
      entry.length,
      sum,
    );
    final int comboCount = combos?.length ?? 999;
    considered++;
    totalComboCount += comboCount;
    if (comboCount == 1) {
      singleCount++;
    }
    if (comboCount > maxComboCount) {
      maxComboCount = comboCount;
    }
  }
  if (considered <= 0) {
    return -1000000;
  }
  return (singleCount * 100000) -
      (totalComboCount * 1000) -
      (maxComboCount * 100);
}

List<int> _collectImplicatedCells(
  KakuroLayout layout,
  _KakuroDisagreementFocus focus,
) {
  final Set<int> cells = <int>{};
  for (final int runId in focus.runIds) {
    if (runId < 0 || runId >= layout.entries.length) {
      continue;
    }
    cells.addAll(layout.entries[runId].cells);
  }
  if (cells.isEmpty && focus.hasBoundingBox) {
    for (int row = focus.minRow; row <= focus.maxRow; row++) {
      for (int col = focus.minCol; col <= focus.maxCol; col++) {
        final int cell = row * layout.width + col;
        if (cell >= 0 &&
            cell < layout.width * layout.height &&
            layout.kinds[cell] == KakuroCellKind.value) {
          cells.add(cell);
        }
      }
    }
  }
  final List<int> ordered = cells.toList(growable: false);
  final int centerRow = focus.centerRow >= 0
      ? focus.centerRow
      : layout.height ~/ 2;
  final int centerCol = focus.centerCol >= 0
      ? focus.centerCol
      : layout.width ~/ 2;
  ordered.sort((int a, int b) {
    final int ar = a ~/ layout.width;
    final int ac = a % layout.width;
    final int br = b ~/ layout.width;
    final int bc = b % layout.width;
    final int aDist = (ar - centerRow).abs() + (ac - centerCol).abs();
    final int bDist = (br - centerRow).abs() + (bc - centerCol).abs();
    if (aDist != bDist) {
      return aDist.compareTo(bDist);
    }
    if (ar != br) {
      return ar.compareTo(br);
    }
    return ac.compareTo(bc);
  });
  return ordered;
}

KakuroLayout? _mutateLayoutAroundImplicatedRegion({
  required KakuroLayout template,
  required _KakuroDisagreementFocus focus,
}) {
  final List<List<int>> grid = _rowsToGrid(template.layout);
  final List<int> cells = _collectImplicatedCells(template, focus);
  if (cells.isEmpty) {
    return null;
  }

  final Set<String> seen = <String>{};
  final List<List<int>> candidates = <List<int>>[];
  void addCandidate(int row, int col) {
    final String key = '$row:$col';
    if (seen.add(key)) {
      candidates.add(<int>[row, col]);
    }
  }

  for (final int cell in cells) {
    final int row = cell ~/ template.width;
    final int col = cell % template.width;
    addCandidate(row, col);
    addCandidate(row - 1, col);
    addCandidate(row + 1, col);
    addCandidate(row, col - 1);
    addCandidate(row, col + 1);
  }

  final int centerRow = focus.centerRow >= 0
      ? focus.centerRow
      : template.height ~/ 2;
  final int centerCol = focus.centerCol >= 0
      ? focus.centerCol
      : template.width ~/ 2;
  candidates.sort((List<int> a, List<int> b) {
    final int aDist = (a[0] - centerRow).abs() + (a[1] - centerCol).abs();
    final int bDist = (b[0] - centerRow).abs() + (b[1] - centerCol).abs();
    if (aDist != bDist) {
      return aDist.compareTo(bDist);
    }
    if (a[0] != b[0]) {
      return a[0].compareTo(b[0]);
    }
    return a[1].compareTo(b[1]);
  });

  final String baselineHash = _computeLayoutHash(template.layout);
  for (final List<int> candidate in candidates) {
    final int row = candidate[0];
    final int col = candidate[1];
    if (row <= 0 ||
        col <= 0 ||
        row >= template.height - 1 ||
        col >= template.width - 1) {
      continue;
    }
    final int current = grid[row][col];
    final int toggled = current == 1 ? 0 : 1;
    if (!_trySetSymmetricValue(grid, row, col, toggled)) {
      continue;
    }
    final KakuroLayout mutated = KakuroLayout.fromRows(
      _gridToRows(grid),
      layoutFamilyId: template.layoutFamilyId,
    );
    if (_isStructurallyValidLayout(mutated) &&
        _computeLayoutHash(mutated.layout) != baselineHash) {
      return mutated;
    }
    _trySetSymmetricValue(grid, row, col, current, force: true);
  }
  return null;
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

_KakuroGridSize _chooseGridSize(GeneratorContext context, String level) {
  final int requestedWidth = context.size.width;
  final int requestedHeight = context.size.height;
  if (requestedWidth <= 0 || requestedHeight <= 0) {
    return _KakuroGridSize.fromSizeId(
      KakuroSupportedProfiles.generatorSizeForDifficulty(level),
    );
  }
  if (KakuroSupportedProfiles.isGeneratorSizeSupported(
    width: requestedWidth,
    height: requestedHeight,
  )) {
    return _KakuroGridSize(width: requestedWidth, height: requestedHeight);
  }
  final List<String> supported =
      KakuroSupportedProfiles.supportedGeneratorSizeIds.toList(growable: false)
        ..sort();
  throw ArgumentError(
    'Unsupported Kakuro size ${requestedWidth}x$requestedHeight for level "$level". '
    'Supported sizes: ${supported.join(', ')}.',
  );
}

class _KakuroGridSize {
  const _KakuroGridSize({required this.width, required this.height});

  factory _KakuroGridSize.fromSizeId(String sizeId) {
    final List<String> parts = sizeId.split('x');
    if (parts.length != 2) {
      throw ArgumentError('Invalid Kakuro size profile: $sizeId');
    }
    return _KakuroGridSize(
      width: int.parse(parts[0]),
      height: int.parse(parts[1]),
    );
  }

  final int width;
  final int height;
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
  final int area = width * height;
  if (width == 9 &&
      height == 9 &&
      (difficulty == 'medium' ||
          difficulty == 'hard' ||
          difficulty == 'expert')) {
    return 24;
  }
  if (width == 7 && height == 7 && difficulty == 'easy') {
    return 12;
  }
  if (area >= 90) {
    return 16;
  }
  if (area >= 63) {
    return 12;
  }
  if (area >= 49) {
    return 10;
  }
  if (area >= 35) {
    return 8;
  }
  return 6;
}

int _layoutEarlyAcceptScoreThreshold({
  required int width,
  required int height,
  required String difficulty,
}) {
  if (width == 9 &&
      height == 9 &&
      (difficulty == 'medium' ||
          difficulty == 'hard' ||
          difficulty == 'expert')) {
    return 1001;
  }
  return 1000;
}

Map<String, int>? _nonUniqueDisagreementMetrics(
  Map<String, Object?> telemetry,
) {
  final Object? summaryRaw = telemetry['disagreementSummary'];
  if (summaryRaw is! Map) {
    return null;
  }
  final Map<String, Object?> summary = Map<String, Object?>.from(summaryRaw);
  final int disagreementCellCount =
      (summary['disagreementCellCount'] as num?)?.toInt() ?? -1;
  final int disagreementMaxRunLength =
      (summary['disagreementMaxRunLength'] as num?)?.toInt() ?? -1;
  final int acrossRunCount =
      (summary['disagreementAcrossRunCount'] as num?)?.toInt() ?? 0;
  final int downRunCount =
      (summary['disagreementDownRunCount'] as num?)?.toInt() ?? 0;
  final int disagreementRunCount =
      (summary['disagreementRunCount'] as num?)?.toInt() ??
      (acrossRunCount + downRunCount);
  if (disagreementCellCount < 0 ||
      disagreementRunCount < 0 ||
      disagreementMaxRunLength < 0) {
    return null;
  }
  return <String, int>{
    'disagreementCellCount': disagreementCellCount,
    'disagreementRunCount': disagreementRunCount,
    'disagreementMaxRunLength': disagreementMaxRunLength,
  };
}

String _buildNonUniqueSignature({
  required String layoutHash,
  required Map<String, Object?> telemetry,
}) {
  final Map<String, int>? disagreement = _nonUniqueDisagreementMetrics(
    telemetry,
  );
  if (disagreement == null) {
    return '$layoutHash:unknown';
  }
  return '$layoutHash:${disagreement['disagreementCellCount']}:${disagreement['disagreementRunCount']}:${disagreement['disagreementMaxRunLength']}';
}

Set<String> _acceptedDifficultyBuckets({
  required String requested,
  required bool allowFallback,
}) {
  switch (requested) {
    case 'easy':
      return allowFallback
          ? const <String>{'easy', 'medium'}
          : const <String>{'easy'};
    case 'medium':
      return allowFallback
          ? const <String>{'medium', 'hard', 'expert'}
          : const <String>{'medium', 'hard'};
    case 'hard':
      return allowFallback
          ? const <String>{'hard', 'expert'}
          : const <String>{'hard', 'expert'};
    case 'expert':
      return const <String>{'expert'};
    default:
      return const <String>{'easy', 'medium', 'hard', 'expert'};
  }
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
      final bool minLogicPressure =
          searchNodes >= 2 ||
          backtracks >= 1 ||
          maxDepth >= 1 ||
          avgRunCombinationCount >= 1.20 ||
          singleComboRunRatio <= 0.95;
      return minLogicPressure &&
          searchNodes <= 120 &&
          backtracks <= 70 &&
          maxDepth <= 8 &&
          maxBranchingFactor <= 7 &&
          avgRunCombinationCount <= 4.6 &&
          singleComboRunRatio >= 0.01 &&
          propagationRounds <= 320;
    case 'hard':
      final bool minLogicPressure =
          searchNodes >= 4 ||
          backtracks >= 2 ||
          maxDepth >= 2 ||
          avgRunCombinationCount >= 1.35 ||
          singleComboRunRatio <= 0.88;
      return minLogicPressure &&
          searchNodes <= 260 &&
          backtracks <= 150 &&
          maxDepth <= 12 &&
          maxBranchingFactor <= 8 &&
          avgRunCombinationCount <= 5.8 &&
          singleComboRunRatio <= 0.97 &&
          propagationRounds <= 520;
    case 'expert':
      final bool minLogicPressure =
          searchNodes >= 8 ||
          backtracks >= 4 ||
          maxDepth >= 3 ||
          avgRunCombinationCount >= 1.55 ||
          singleComboRunRatio <= 0.80;
      return minLogicPressure &&
          searchNodes <= 640 &&
          backtracks <= 360 &&
          maxDepth <= 16 &&
          maxBranchingFactor <= 9 &&
          avgRunCombinationCount <= 7.5 &&
          singleComboRunRatio <= 0.90 &&
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
