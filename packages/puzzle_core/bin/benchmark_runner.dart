import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:puzzle_core/puzzle_core.dart';
import 'package:puzzle_core/src/kakuro/kakuro_generator.dart';
import 'package:puzzle_core/src/mathdoku/mathdoku_solver.dart';

/// Standalone benchmark runner for puzzle engines.
///
/// This can be called from the main bench.dart script to run actual
/// puzzle engine benchmarks in a separate process.
void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print(
      'Usage: dart benchmark_runner.dart <engineId> <count> <difficulty> <size> [iterationCapMs] [--kakuro-profile=<name>] [--enforce-experimental-kakuro-gate]',
    );
    print('');
    print('Or run a named Kakuro profile directly:');
    print(
      '  dart benchmark_runner.dart <kakuro_profile_name> [iterationCapMs] [--enforce-experimental-kakuro-gate]',
    );
    exit(1);
  }

  String engineId;
  int count;
  String difficulty;
  String size;
  int iterationCapMs = 8000;
  String? kakuroProfileName;
  bool enforceExperimentalKakuroGate = false;

  if (_kakuroBenchmarkProfiles.containsKey(arguments.first)) {
    final _KakuroBenchmarkProfile profile =
        _kakuroBenchmarkProfiles[arguments.first]!;
    engineId = 'kakuro_classic';
    count = profile.seedCorpus.length;
    difficulty = profile.difficulty;
    size = profile.sizeId;
    kakuroProfileName = profile.name;
    for (final String arg in arguments.skip(1)) {
      if (arg == '--enforce-experimental-kakuro-gate') {
        enforceExperimentalKakuroGate = true;
        continue;
      }
      final int? maybeCap = int.tryParse(arg);
      if (maybeCap != null) {
        iterationCapMs = maybeCap;
      }
    }
  } else {
    if (arguments.length < 4) {
      print(
        'Usage: dart benchmark_runner.dart <engineId> <count> <difficulty> <size> [iterationCapMs] [--kakuro-profile=<name>] [--enforce-experimental-kakuro-gate]',
      );
      exit(1);
    }
    engineId = arguments[0];
    count = int.parse(arguments[1]);
    difficulty = arguments[2];
    size = arguments[3];
    if (arguments.length >= 5) {
      final int? maybeCap = int.tryParse(arguments[4]);
      if (maybeCap != null) {
        iterationCapMs = maybeCap;
      }
    }
    for (final String arg in arguments.skip(4)) {
      if (arg.startsWith('--kakuro-profile=')) {
        kakuroProfileName = arg.substring('--kakuro-profile='.length).trim();
      } else if (arg == '--enforce-experimental-kakuro-gate') {
        enforceExperimentalKakuroGate = true;
      }
    }
  }

  try {
    // Initialize engines
    await _initializeEngines();

    // Run benchmark
    final result = await _benchmarkEngine(
      engineId: engineId,
      count: count,
      difficulty: difficulty,
      size: size,
      iterationCapMs: iterationCapMs,
      kakuroBenchmarkProfileName: kakuroProfileName,
      enforceExperimentalKakuroGate: enforceExperimentalKakuroGate,
    );

    // Output result as JSON
    print(jsonEncode(result.toJson()));
    if (!result.success) {
      exit(1);
    }
  } catch (e) {
    final errorResult = EngineBenchmarkResult(
      engineId: engineId,
      success: false,
      error: e.toString(),
      p50Ms: 0,
      p95Ms: 0,
      p99Ms: 0,
      totalTimeMs: 0,
      iterations: 0,
    );
    print(jsonEncode(errorResult.toJson()));
    exit(1);
  }
}

/// Initialize all available engines.
Future<void> _initializeEngines() async {
  final registry = EngineRegistry();

  // Register stub engines
  registry.register(StubPuzzleEngine());
  registry.register(StubSudokuEngine());

  // Register real engines (with error handling)
  try {
    registry.register(SudokuEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(NonogramEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(KakuroEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(SlitherlinkEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(MathdokuEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(KillerQueensEngine());
  } catch (e) {
    // Engine might not be available
  }

  try {
    registry.register(TakuzuEngine());
  } catch (e) {
    // Engine might not be available
  }
}

PuzzleEngine<dynamic, dynamic> _createBenchmarkEngine({
  required String engineId,
  required int iterationCapMs,
}) {
  switch (engineId) {
    case 'sudoku_classic':
      return SudokuEngine();
    case 'nonogram_mono':
      return NonogramEngine();
    case 'kakuro_classic':
      return KakuroEngine(
        generator: KakuroGenerator(
          hardTimeLimitOverride: Duration(milliseconds: iterationCapMs),
        ),
      );
    case 'slitherlink_loop':
      return SlitherlinkEngine();
    case 'mathdoku_classic':
      return MathdokuEngine();
    case 'killer_queens':
      return KillerQueensEngine();
    case 'takuzu_binary':
      return TakuzuEngine();
    default:
      return StubPuzzleEngine(engineId: engineId);
  }
}

/// Benchmark a single engine.
Future<EngineBenchmarkResult> _benchmarkEngine({
  required String engineId,
  required int count,
  required String difficulty,
  required String size,
  required int iterationCapMs,
  String? kakuroBenchmarkProfileName,
  bool enforceExperimentalKakuroGate = false,
}) async {
  final registry = EngineRegistry();
  PuzzleEngine<dynamic, dynamic>? engine = registry.getEngine(engineId);
  const KakuroSolver kakuroSolver = KakuroSolver();
  final bool measureKakuroUniqueness = engineId == 'kakuro_classic';

  // Parse size
  final sizeParts = size.split('x');
  if (sizeParts.length != 2) {
    throw Exception('Invalid size format: $size');
  }
  final width = int.parse(sizeParts[0]);
  final height = int.parse(sizeParts[1]);
  final String normalizedDifficulty =
      KakuroSupportedProfiles.normalizeDifficulty(difficulty);
  final String sizeId = '${width}x$height';
  int iterationCount = count;
  _KakuroBenchmarkProfile? kakuroProfile;
  if (kakuroBenchmarkProfileName != null &&
      kakuroBenchmarkProfileName.trim().isNotEmpty) {
    kakuroProfile = _kakuroBenchmarkProfiles[kakuroBenchmarkProfileName.trim()];
    if (kakuroProfile == null) {
      throw Exception(
        'Unknown Kakuro benchmark profile "$kakuroBenchmarkProfileName". '
        'Available: ${_kakuroBenchmarkProfiles.keys.join(', ')}',
      );
    }
    if (!measureKakuroUniqueness) {
      throw Exception(
        'Kakuro benchmark profiles are only supported with engineId=kakuro_classic.',
      );
    }
    if (kakuroProfile.sizeId != sizeId ||
        kakuroProfile.difficulty != normalizedDifficulty) {
      throw Exception(
        'Kakuro profile ${kakuroProfile.name} expects '
        '${kakuroProfile.sizeId}/${kakuroProfile.difficulty}, '
        'but got $sizeId/$normalizedDifficulty.',
      );
    }
    iterationCount = kakuroProfile.seedCorpus.length;
  }
  if (measureKakuroUniqueness &&
      !KakuroSupportedProfiles.isBenchmarkEligible(
        sizeId: sizeId,
        difficulty: normalizedDifficulty,
      )) {
    throw Exception(
      'Unsupported Kakuro benchmark profile $sizeId/$normalizedDifficulty. '
      'Use a shipping, benchmark-only, or experimental Kakuro profile.',
    );
  }

  if (measureKakuroUniqueness) {
    engine = KakuroEngine(
      generator: KakuroGenerator(
        hardTimeLimitOverride: Duration(milliseconds: iterationCapMs),
      ),
    );
  }

  if (engine == null) {
    throw Exception('Engine not found: $engineId');
  }

  if (engineId == 'mathdoku_classic' && width == 9 && height == 9) {
    return _benchmarkMathdoku9x9(
      engine: engine,
      engineId: engineId,
      count: count,
      requestedDifficulty: difficulty,
      width: width,
      height: height,
    );
  }

  // Parse difficulty
  final difficultyScore = _parseDifficulty(difficulty);

  final times = <int>[];
  final List<int> uniquenessSolveTimes = <int>[];
  final List<Map<String, Object?>> iterationDetails = <Map<String, Object?>>[];
  int primaryAcceptCount = 0;
  int repairedAcceptCount = 0;
  int repairedRejectCount = 0;
  int generationFailureCount = 0;
  int uniquenessFailureCount = 0;
  int nonUniqueCount = 0;
  int unknownStatusCount = 0;
  int layoutGateCount = 0;
  int repairAttemptCount = 0;
  int difficultyMatchSamples = 0;
  int difficultyMatchCount = 0;
  final Map<String, int> measuredDifficultyDistribution = <String, int>{};
  final Map<String, int> layoutFamilyDistribution = <String, int>{};
  final List<String> seedCorpus =
      kakuroProfile?.seedCorpus ??
      List<String>.generate(
        iterationCount,
        (int i) => 'bench:$engineId:$i',
        growable: false,
      );
  Map<String, Object?>? slowestIteration;
  final totalStopwatch = Stopwatch()..start();
  for (int i = 0; i < seedCorpus.length; i++) {
    final seedStr = seedCorpus[i];
    final seed64 = Seed.fromString(seedStr);

    final stopwatch = Stopwatch()..start();
    GeneratedPuzzle<dynamic>? puzzle;
    Object? generationError;

    try {
      final SizeOpt benchmarkSize = SizeOpt(
        id: '${width}x$height',
        description: '${width}x$height',
        width: width,
        height: height,
      );
      if (measureKakuroUniqueness) {
        puzzle = await Isolate.run(() {
          final PuzzleEngine<dynamic, dynamic> isolatedEngine =
              _createBenchmarkEngine(
                engineId: engineId,
                iterationCapMs: iterationCapMs,
              );
          return isolatedEngine.generate(
            seedStr: seedStr,
            seed64: seed64,
            size: benchmarkSize,
            difficulty: difficultyScore,
          );
        }).timeout(Duration(milliseconds: iterationCapMs));
      } else {
        puzzle = engine.generate(
          seedStr: seedStr,
          seed64: seed64,
          size: benchmarkSize,
          difficulty: difficultyScore,
        );
      }

      // Basic validation
      if (puzzle.meta.engineVersion.isEmpty) {
        throw Exception('Invalid puzzle generated');
      }
    } on TimeoutException catch (e) {
      generationError = GenerationFailure(
        message:
            'Benchmark iteration exceeded cap of ${iterationCapMs}ms '
            'for seed $seedStr',
        attempts: 1,
        elapsed: Duration(milliseconds: iterationCapMs),
        baseSeed: seed64,
        lastError: e,
        context: <String, Object?>{
          'failureReason': 'benchmark_iteration_timeout',
          'iterationCapMs': iterationCapMs,
          'seed': seedStr,
          'size': '${width}x$height',
          'difficulty': difficulty,
        },
      );
    } catch (e) {
      generationError = e;
    }

    stopwatch.stop();
    final int generationMicros = stopwatch.elapsedMicroseconds;
    final double generationMs = generationMicros / 1000.0;
    final Map<String, Object?> generatorTelemetry = _asObjectMap(
      puzzle?.telemetry?.extras['generator'],
    );
    final String? measuredBucket =
        generatorTelemetry['measuredDifficultyBucket'] as String? ??
        generatorTelemetry['difficultyBucket'] as String?;
    final Object? attemptCount = generatorTelemetry['attempts'];
    final Object? rejectCounters = generatorTelemetry['rejectCounters'];
    final Object? hardCapExceeded = generatorTelemetry['hardCapExceeded'];
    final Map<String, Object?> detail = <String, Object?>{
      'iteration': i,
      'seed': seedStr,
      'generationMs': generationMs,
      'selectedSize': generatorTelemetry['selectedSize'] ?? '${width}x$height',
      if (measuredBucket != null) 'measuredBucket': measuredBucket,
      if (attemptCount != null) 'attempts': attemptCount,
      if (rejectCounters != null) 'rejectCounters': rejectCounters,
      if (hardCapExceeded != null) 'hardCapExceeded': hardCapExceeded,
    };
    const List<String> kakuroTelemetryFields = <String>[
      'layoutHash',
      'layoutFamilyId',
      'whiteCellCount',
      'blockCellCount',
      'clueCellCount',
      'blackOrClueCellCount',
      'acrossRunCount',
      'downRunCount',
      'totalRunCount',
      'runLengthHistogram',
      'maxRunLength',
      'averageRunLengthMilli',
      'runGraphNodeCount',
      'runGraphEdgeCount',
      'minRunGraphDegree',
      'articulationPointCount',
      'averageRunCombinationCountMilli',
      'singleCombinationRunRatioMilli',
      'stageTimingMs',
      'repairAttemptCount',
      'repairOutcome',
      'repairReason',
      'repairedFromNonUnique',
      'repairedRejectCount',
      'acceptPath',
      'finalLayoutHash',
    ];
    for (final String field in kakuroTelemetryFields) {
      final Object? value = generatorTelemetry[field];
      if (value != null) {
        detail[field] = value;
      }
    }

    if (generationError != null) {
      generationFailureCount++;
      if (generationError is GenerationFailure) {
        final GenerationFailure failure = generationError;
        detail['generationFailureContext'] = _sanitizeFailureContext(
          failure.context,
        );
        final Map<String, Object?> rejectCounters = _asObjectMap(
          failure.context['rejectCounters'],
        );
        layoutGateCount += _asInt(rejectCounters['layoutGate'], fallback: 0);
        nonUniqueCount += _asInt(rejectCounters['nonUnique'], fallback: 0);
        unknownStatusCount += _asInt(
          rejectCounters['unknownStatus'],
          fallback: 0,
        );
        repairAttemptCount += _asInt(
          failure.context['repairAttemptCount'],
          fallback: 0,
        );
      }
      detail['status'] = 'generation_failed';
      detail['error'] = generationError.toString();
      iterationDetails.add(detail);
      continue;
    }

    times.add(generationMicros);
    detail['status'] = 'generated';

    final bool repairedAccept =
        generatorTelemetry['repairedFromNonUnique'] == true ||
        generatorTelemetry['acceptPath'] == 'repaired';
    if (repairedAccept) {
      repairedAcceptCount++;
      detail['acceptPath'] = 'repaired';
    } else {
      primaryAcceptCount++;
      detail['acceptPath'] = 'primary';
    }
    repairedRejectCount += _asInt(
      generatorTelemetry['repairedRejectCount'],
      fallback: 0,
    );
    repairAttemptCount += _asInt(
      generatorTelemetry['repairAttemptCount'],
      fallback: 0,
    );
    layoutGateCount += _asInt(
      _asObjectMap(generatorTelemetry['rejectCounters'])['layoutGate'],
      fallback: 0,
    );
    nonUniqueCount += _asInt(
      _asObjectMap(generatorTelemetry['rejectCounters'])['nonUnique'],
      fallback: 0,
    );
    unknownStatusCount += _asInt(
      _asObjectMap(generatorTelemetry['rejectCounters'])['unknownStatus'],
      fallback: 0,
    );
    if (measuredBucket != null && measuredBucket.isNotEmpty) {
      measuredDifficultyDistribution[measuredBucket] =
          (measuredDifficultyDistribution[measuredBucket] ?? 0) + 1;
    }
    final Object? difficultyMatched =
        generatorTelemetry['difficultyMatchedRequest'];
    if (difficultyMatched is bool) {
      difficultyMatchSamples++;
      if (difficultyMatched) {
        difficultyMatchCount++;
      }
    }
    final String? layoutFamily = generatorTelemetry['layoutFamilyId']
        ?.toString();
    if (layoutFamily != null && layoutFamily.isNotEmpty) {
      layoutFamilyDistribution[layoutFamily] =
          (layoutFamilyDistribution[layoutFamily] ?? 0) + 1;
    }

    if (measureKakuroUniqueness) {
      if (puzzle == null || puzzle.state is! KakuroBoard) {
        detail['status'] = 'generation_failed';
        detail['error'] = 'Kakuro benchmark expected KakuroBoard state';
        iterationDetails.add(detail);
        generationFailureCount++;
        continue;
      }
      final Stopwatch solveWatch = Stopwatch()..start();
      final SolverResult<KakuroBoard> solved = kakuroSolver.solve(
        puzzle.state as KakuroBoard,
        SolverContext(rng: SeededRng(seed64 ^ 0x7f4a7c15), maxSolutions: 2),
      );
      solveWatch.stop();
      final int solveMicros = solveWatch.elapsedMicroseconds;
      detail['uniquenessSolveMs'] = solveMicros / 1000.0;
      if (!solved.hasSolution || !solved.isUnique) {
        uniquenessFailureCount++;
        if (solved.solutionStatus == SolverStatus.multiple) {
          nonUniqueCount++;
        } else if (solved.solutionStatus == SolverStatus.unknown) {
          unknownStatusCount++;
        }
        detail['status'] = 'uniqueness_failed';
        detail['solverStatus'] = solved.solutionStatus.name;
        detail['error'] =
            'Kakuro uniqueness solve failed for seed $seedStr: ${solved.solutionStatus.name}';
        iterationDetails.add(detail);
        continue;
      }
      uniquenessSolveTimes.add(solveMicros);
      detail['solverStatus'] = solved.solutionStatus.name;
    }
    detail['status'] = 'success';
    iterationDetails.add(detail);
    final double previousSlowestMs =
        (slowestIteration?['generationMs'] as double?) ?? -1.0;
    if (generationMs > previousSlowestMs) {
      slowestIteration = detail;
    }
  }

  totalStopwatch.stop();

  // Calculate percentiles
  final List<int> sortedTimes = List<int>.from(times)..sort();
  final p50 = _percentile(sortedTimes, 0.50);
  final p95 = _percentile(sortedTimes, 0.95);
  final p99 = _percentile(sortedTimes, 0.99);
  final int totalIterations = seedCorpus.length;
  final int successfulIterations =
      totalIterations - generationFailureCount - uniquenessFailureCount;
  final double successRate = totalIterations == 0
      ? 0.0
      : successfulIterations / totalIterations;
  final Map<String, Object?> extras = <String, Object?>{
    'size': '${width}x$height',
    'requestedDifficulty': difficulty,
    'iterationCapMs': iterationCapMs,
    'seedCorpus': seedCorpus,
    'iterationDurationsMs': iterationDetails
        .map((Map<String, Object?> detail) => detail['generationMs'] as double)
        .toList(growable: false),
    if (slowestIteration != null) 'slowestIteration': slowestIteration,
    'iterationDetails': iterationDetails,
    'acceptBreakdown': <String, int>{
      'primaryAccepts': primaryAcceptCount,
      'repairedAccepts': repairedAcceptCount,
      'repairedRejects': repairedRejectCount,
    },
    if (measureKakuroUniqueness)
      'kakuroMetrics': <String, Object?>{
        'successRate': successRate,
        'successfulCount': successfulIterations,
        'generationFailureCount': generationFailureCount,
        'uniquenessFailureCount': uniquenessFailureCount,
        'nonUniqueCount': nonUniqueCount,
        'unknownStatusCount': unknownStatusCount,
        'layoutGateCount': layoutGateCount,
        if (repairAttemptCount > 0) 'repairCount': repairAttemptCount,
        'generationMs': <String, double>{
          'p50': _percentile(sortedTimes, 0.50) / 1000.0,
          'p95': _percentile(sortedTimes, 0.95) / 1000.0,
          'p99': _percentile(sortedTimes, 0.99) / 1000.0,
        },
        'measuredDifficultyDistribution': measuredDifficultyDistribution,
        'difficultyMatchRate': difficultyMatchSamples == 0
            ? 0.0
            : difficultyMatchCount / difficultyMatchSamples,
        'layoutFamilyDistribution': layoutFamilyDistribution,
      },
  };
  Map<String, Object?>? kakuroMetrics;
  if (measureKakuroUniqueness) {
    kakuroMetrics = Map<String, Object?>.from(extras['kakuroMetrics'] as Map);
    extras['kakuroMetrics'] = kakuroMetrics;
  }
  if (measureKakuroUniqueness && uniquenessSolveTimes.isNotEmpty) {
    final List<int> sortedUniqueness = List<int>.from(uniquenessSolveTimes)
      ..sort();
    final Map<String, double> uniquenessSummary = <String, double>{
      'p50': _percentile(sortedUniqueness, 0.50) / 1000.0,
      'p95': _percentile(sortedUniqueness, 0.95) / 1000.0,
      'p99': _percentile(sortedUniqueness, 0.99) / 1000.0,
    };
    extras['uniquenessSolveMs'] = uniquenessSummary;
    kakuroMetrics?['uniquenessSolveMs'] = uniquenessSummary;
  }
  if (kakuroProfile != null) {
    extras['benchmarkMode'] = 'kakuro_profile_corpus_v1';
    extras['kakuroProfile'] = kakuroProfile.toJson();
    final _KakuroBenchmarkGateResult gate = _evaluateKakuroGate(
      profile: kakuroProfile,
      successRate: successRate,
      generationP95Ms: sortedTimes.isEmpty
          ? 0.0
          : _percentile(sortedTimes, 0.95) / 1000.0,
      uniquenessP95Ms: uniquenessSolveTimes.isEmpty
          ? 0.0
          : _percentile(List<int>.from(uniquenessSolveTimes)..sort(), 0.95) /
                1000.0,
      unknownStatusCount: unknownStatusCount,
      difficultyMatchRate: difficultyMatchSamples == 0
          ? 0.0
          : difficultyMatchCount / difficultyMatchSamples,
      enforceExperimentalGate: enforceExperimentalKakuroGate,
    );
    extras['kakuroGate'] = gate.toJson();
    if (gate.enforced && !gate.passed) {
      return EngineBenchmarkResult(
        engineId: engineId,
        success: false,
        error:
            'Kakuro benchmark gate failed for profile ${kakuroProfile.name}: ${gate.failures.join('; ')}',
        p50Ms: p50 / 1000.0,
        p95Ms: p95 / 1000.0,
        p99Ms: p99 / 1000.0,
        totalTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
        iterations: totalIterations,
        extras: extras,
      );
    }
  } else if (measureKakuroUniqueness) {
    extras['benchmarkMode'] = 'kakuro_phone_v1_calibration';
    if (generationFailureCount > 0 || uniquenessFailureCount > 0) {
      return EngineBenchmarkResult(
        engineId: engineId,
        success: false,
        error:
            'Kakuro benchmark had failures: generation=$generationFailureCount, uniqueness=$uniquenessFailureCount',
        p50Ms: p50 / 1000.0,
        p95Ms: p95 / 1000.0,
        p99Ms: p99 / 1000.0,
        totalTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
        iterations: totalIterations,
        extras: extras,
      );
    }
  }

  return EngineBenchmarkResult(
    engineId: engineId,
    success: true,
    error: null,
    p50Ms: p50 / 1000.0,
    p95Ms: p95 / 1000.0,
    p99Ms: p99 / 1000.0,
    totalTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
    iterations: totalIterations,
    extras: extras,
  );
}

EngineBenchmarkResult _benchmarkMathdoku9x9({
  required PuzzleEngine engine,
  required String engineId,
  required int count,
  required String requestedDifficulty,
  required int width,
  required int height,
}) {
  if (engine is! MathdokuEngine) {
    throw Exception('Engine $engineId is not a MathdokuEngine');
  }

  final List<String> difficulties = _resolveMathdokuDifficulties(
    requestedDifficulty,
  );
  if (difficulties.isEmpty) {
    throw Exception(
      'Unsupported Mathdoku benchmark difficulty: $requestedDifficulty. '
      'Use easy|medium|hard|expert|all (or comma-separated list).',
    );
  }

  final DifficultyBucketConfig thresholds = const DifficultyConfigLoader()
      .loadSync('assets/mathdoku_difficulty_thresholds.json');

  final List<int> allTimes = <int>[];
  final Map<String, Object?> byDifficulty = <String, Object?>{};
  final Stopwatch totalStopwatch = Stopwatch()..start();

  for (final String level in difficulties) {
    byDifficulty[level] = _runMathdokuDifficultyBench(
      engine: engine,
      level: level,
      count: count,
      width: width,
      height: height,
      allTimes: allTimes,
      thresholds: thresholds,
    );
  }

  totalStopwatch.stop();

  if (allTimes.isEmpty) {
    throw Exception('Mathdoku benchmark produced no samples.');
  }

  allTimes.sort();
  final int p50 = _percentile(allTimes, 0.50);
  final int p95 = _percentile(allTimes, 0.95);
  final int p99 = _percentile(allTimes, 0.99);

  return EngineBenchmarkResult(
    engineId: engineId,
    success: true,
    error: null,
    p50Ms: p50 / 1000.0,
    p95Ms: p95 / 1000.0,
    p99Ms: p99 / 1000.0,
    totalTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
    iterations: allTimes.length,
    extras: <String, Object?>{
      'benchmarkMode': 'mathdoku_9x9_calibration',
      'requestedDifficulty': requestedDifficulty,
      'difficulties': difficulties,
      'countPerDifficulty': count,
      'size': '${width}x$height',
      'thresholds': _thresholdSummary(thresholds),
      'byDifficulty': byDifficulty,
      'note':
          'Thresholds are reported for calibration and are not enforced as hard benchmark gates.',
    },
  );
}

Map<String, Object?> _runMathdokuDifficultyBench({
  required MathdokuEngine engine,
  required String level,
  required int count,
  required int width,
  required int height,
  required List<int> allTimes,
  required DifficultyBucketConfig thresholds,
}) {
  final DifficultyScore requested = _parseDifficulty(level);
  final List<int> timeSamplesUs = <int>[];
  final List<double> rawDifficultyScores = <double>[];
  final List<int> searchNodes = <int>[];
  final List<int> searchDepth = <int>[];
  final List<int> branchDecisions = <int>[];
  final List<int> propagationDepth = <int>[];
  final List<String> seedList = <String>[];

  final Map<String, int> observedBuckets = <String, int>{};
  int generationFailures = 0;
  int uniquenessFailures = 0;
  final List<Map<String, String>> failureSamples = <Map<String, String>>[];

  for (int i = 0; i < count; i++) {
    final String seedStr = 'bench:mathdoku_classic:$level:${width}x$height:$i';
    final int seed64 = Seed.fromString(seedStr);
    seedList.add(seedStr);

    final Stopwatch stopwatch = Stopwatch()..start();
    GeneratedPuzzle<MathdokuBoard> puzzle;
    try {
      puzzle = engine.generate(
        seedStr: seedStr,
        seed64: seed64,
        size: SizeOpt(
          id: '${width}x$height',
          description: '${width}x$height',
          width: width,
          height: height,
        ),
        difficulty: requested,
      );
    } catch (e) {
      generationFailures++;
      if (failureSamples.length < 5) {
        failureSamples.add(<String, String>{
          'seed': seedStr,
          'kind': 'generation',
          'error': e.toString(),
        });
      }
      continue;
    } finally {
      stopwatch.stop();
    }

    final int elapsedUs = stopwatch.elapsedMicroseconds;
    timeSamplesUs.add(elapsedUs);
    allTimes.add(elapsedUs);

    final double rawScore =
        puzzle.telemetry?.difficulty.rawScore ?? puzzle.meta.difficulty.value;
    rawDifficultyScores.add(rawScore);

    final String bucket =
        puzzle.telemetry?.difficulty.bucket ?? puzzle.meta.difficulty.level;
    observedBuckets[bucket] = (observedBuckets[bucket] ?? 0) + 1;

    final Map<String, Object?> solverTelemetry = _asObjectMap(
      puzzle.telemetry?.extras['solver'],
    );
    searchNodes.add(_asInt(solverTelemetry['searchNodes'], fallback: 0));
    searchDepth.add(_asInt(solverTelemetry['searchDepth'], fallback: 0));
    branchDecisions.add(
      _asInt(solverTelemetry['branchDecisions'], fallback: 0),
    );
    propagationDepth.add(
      _asInt(solverTelemetry['propagationDepth'], fallback: 0),
    );

    final SolverResult<MathdokuBoard> uniqueness = const MathdokuSolver().solve(
      puzzle.state,
      SolverContext(
        rng: SeededRng(seed64 ^ 0x5bf03635d8e1a1ad),
        maxSolutions: 2,
      ),
    );
    if (!uniqueness.hasSolution || !uniqueness.isUnique) {
      uniquenessFailures++;
      if (failureSamples.length < 5) {
        failureSamples.add(<String, String>{
          'seed': seedStr,
          'kind': 'uniqueness',
          'error': uniqueness.hasSolution
              ? 'non-unique solution count=${uniqueness.solutions.length}'
              : 'unsolved',
        });
      }
    }
  }

  if (generationFailures > 0 || uniquenessFailures > 0) {
    throw Exception(
      'Mathdoku benchmark failed for $level ${width}x$height: '
      'generationFailures=$generationFailures, uniquenessFailures=$uniquenessFailures, '
      'samples=${jsonEncode(failureSamples)}',
    );
  }

  timeSamplesUs.sort();
  rawDifficultyScores.sort();
  searchNodes.sort();
  searchDepth.sort();
  branchDecisions.sort();
  propagationDepth.sort();

  final _BucketWindow thresholdWindow = _thresholdWindowFor(level, thresholds);
  final int belowThreshold = rawDifficultyScores
      .where(
        (double score) =>
            thresholdWindow.minExclusive != null &&
            score <= thresholdWindow.minExclusive!,
      )
      .length;
  final int aboveThreshold = rawDifficultyScores
      .where(
        (double score) =>
            thresholdWindow.maxInclusive != null &&
            score > thresholdWindow.maxInclusive!,
      )
      .length;

  return <String, Object?>{
    'difficulty': level,
    'iterations': timeSamplesUs.length,
    'seedList': seedList,
    'generationTimeMs': _summarizeIntSamplesMicros(timeSamplesUs),
    'rawDifficultyScore': _summarizeDoubleSamples(rawDifficultyScores),
    'rawDifficultyHistogram': _histogram(rawDifficultyScores),
    'observedDifficultyBuckets': observedBuckets,
    'thresholdWindow': thresholdWindow.toJson(),
    'thresholdCalibration': <String, Object?>{
      'belowMinExclusiveCount': belowThreshold,
      'aboveMaxInclusiveCount': aboveThreshold,
      'withinWindowCount':
          rawDifficultyScores.length - belowThreshold - aboveThreshold,
      'enforced': false,
    },
    'solverMetrics': <String, Object?>{
      'searchNodes': _summarizeIntSamples(searchNodes),
      'searchDepth': _summarizeIntSamples(searchDepth),
      'branchDecisions': _summarizeIntSamples(branchDecisions),
      'propagationDepth': _summarizeIntSamples(propagationDepth),
    },
  };
}

List<String> _resolveMathdokuDifficulties(String requestedDifficulty) {
  final String normalized = requestedDifficulty.trim().toLowerCase();
  if (normalized == 'all') {
    return const <String>['easy', 'medium', 'hard', 'expert'];
  }
  final List<String> parsed = normalized
      .split(',')
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toList(growable: false);
  const Set<String> allowed = <String>{'easy', 'medium', 'hard', 'expert'};
  for (final String level in parsed) {
    if (!allowed.contains(level)) {
      return const <String>[];
    }
  }
  return parsed;
}

Map<String, Object?> _thresholdSummary(DifficultyBucketConfig config) {
  return <String, Object?>{
    'buckets': config.buckets
        .map(
          (DifficultyBucketThreshold bucket) => <String, Object?>{
            'id': bucket.id,
            'maxInclusive': bucket.maxInclusive,
          },
        )
        .toList(growable: false),
  };
}

Map<String, Object?> _summarizeIntSamplesMicros(List<int> sortedMicros) {
  if (sortedMicros.isEmpty) {
    return const <String, Object?>{
      'count': 0,
      'minMs': 0.0,
      'maxMs': 0.0,
      'meanMs': 0.0,
      'p50Ms': 0.0,
      'p95Ms': 0.0,
      'p99Ms': 0.0,
      'samplesMs': <double>[],
    };
  }
  final double meanUs =
      sortedMicros.reduce((int a, int b) => a + b) / sortedMicros.length;
  return <String, Object?>{
    'count': sortedMicros.length,
    'minMs': sortedMicros.first / 1000.0,
    'maxMs': sortedMicros.last / 1000.0,
    'meanMs': meanUs / 1000.0,
    'p50Ms': _percentile(sortedMicros, 0.50) / 1000.0,
    'p95Ms': _percentile(sortedMicros, 0.95) / 1000.0,
    'p99Ms': _percentile(sortedMicros, 0.99) / 1000.0,
    'samplesMs': sortedMicros
        .map((int us) => us / 1000.0)
        .toList(growable: false),
  };
}

Map<String, Object?> _summarizeIntSamples(List<int> sortedValues) {
  if (sortedValues.isEmpty) {
    return const <String, Object?>{
      'count': 0,
      'min': 0,
      'max': 0,
      'mean': 0.0,
      'p50': 0,
      'p95': 0,
      'p99': 0,
      'samples': <int>[],
    };
  }
  final double mean =
      sortedValues.reduce((int a, int b) => a + b) / sortedValues.length;
  return <String, Object?>{
    'count': sortedValues.length,
    'min': sortedValues.first,
    'max': sortedValues.last,
    'mean': mean,
    'p50': _percentile(sortedValues, 0.50),
    'p95': _percentile(sortedValues, 0.95),
    'p99': _percentile(sortedValues, 0.99),
    'samples': List<int>.from(sortedValues),
  };
}

Map<String, Object?> _summarizeDoubleSamples(List<double> sortedValues) {
  if (sortedValues.isEmpty) {
    return const <String, Object?>{
      'count': 0,
      'min': 0.0,
      'max': 0.0,
      'mean': 0.0,
      'p50': 0.0,
      'p95': 0.0,
      'p99': 0.0,
      'samples': <double>[],
    };
  }
  final double mean =
      sortedValues.reduce((double a, double b) => a + b) / sortedValues.length;
  return <String, Object?>{
    'count': sortedValues.length,
    'min': sortedValues.first,
    'max': sortedValues.last,
    'mean': mean,
    'p50': _percentileDouble(sortedValues, 0.50),
    'p95': _percentileDouble(sortedValues, 0.95),
    'p99': _percentileDouble(sortedValues, 0.99),
    'samples': List<double>.from(sortedValues),
  };
}

Map<String, Object?> _histogram(List<double> sortedValues, {int bins = 12}) {
  if (sortedValues.isEmpty) {
    return const <String, Object?>{'bins': <Object?>[]};
  }

  final double min = sortedValues.first;
  final double max = sortedValues.last;
  if (max == min) {
    return <String, Object?>{
      'bins': <Map<String, Object?>>[
        <String, Object?>{
          'start': min,
          'end': max,
          'count': sortedValues.length,
        },
      ],
    };
  }

  final int safeBins = bins < 1 ? 1 : bins;
  final double width = (max - min) / safeBins;
  final List<int> counts = List<int>.filled(safeBins, 0);
  for (final double value in sortedValues) {
    int index = ((value - min) / width).floor();
    if (index >= safeBins) {
      index = safeBins - 1;
    }
    if (index < 0) {
      index = 0;
    }
    counts[index]++;
  }

  final List<Map<String, Object?>> resultBins = <Map<String, Object?>>[];
  for (int i = 0; i < safeBins; i++) {
    resultBins.add(<String, Object?>{
      'start': min + width * i,
      'end': i == safeBins - 1 ? max : min + width * (i + 1),
      'count': counts[i],
    });
  }
  return <String, Object?>{'bins': resultBins};
}

Map<String, Object?> _asObjectMap(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  return const <String, Object?>{};
}

Map<String, Object?> _sanitizeFailureContext(Map<String, Object?> context) {
  final Map<String, Object?> sanitized = Map<String, Object?>.from(context);
  final Object? attemptsLogRaw = context['attemptsLog'];
  if (attemptsLogRaw is List) {
    final List<Map<String, Object?>> trimmed = <Map<String, Object?>>[];
    for (final Object? item in attemptsLogRaw.take(8)) {
      if (item is! Map) {
        continue;
      }
      final Map<String, Object?> attempt = Map<String, Object?>.from(item);
      final Map<String, Object?> compact = <String, Object?>{
        if (attempt['attempt'] != null) 'attempt': attempt['attempt'],
        if (attempt['durationMs'] != null) 'durationMs': attempt['durationMs'],
        if (attempt['outcome'] != null) 'outcome': attempt['outcome'],
        if (attempt['rejectReason'] != null)
          'rejectReason': attempt['rejectReason'],
        if (attempt['solverStatus'] != null)
          'solverStatus': attempt['solverStatus'],
        if (attempt['mode'] != null) 'mode': attempt['mode'],
        if (attempt['repairPass'] != null) 'repairPass': attempt['repairPass'],
        if (attempt['repairStrategy'] != null)
          'repairStrategy': attempt['repairStrategy'],
        if (attempt['repairOutcome'] != null)
          'repairOutcome': attempt['repairOutcome'],
        if (attempt['repairReason'] != null)
          'repairReason': attempt['repairReason'],
        if (attempt['layoutHash'] != null) 'layoutHash': attempt['layoutHash'],
      };
      final Map<String, Object?> construction = _asObjectMap(
        attempt['constructionTelemetry'],
      );
      if (construction.isNotEmpty) {
        compact['constructionTelemetry'] = <String, Object?>{
          if (construction['constructionScoreMilli'] != null)
            'constructionScoreMilli': construction['constructionScoreMilli'],
        };
      }
      trimmed.add(compact);
    }
    sanitized['attemptsLog'] = trimmed;
    sanitized['attemptsLogSampled'] = true;
    sanitized['attemptsLogOriginalCount'] = attemptsLogRaw.length;
  }
  return sanitized;
}

int _asInt(Object? value, {required int fallback}) {
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}

double _percentileDouble(List<double> sortedList, double percentile) {
  if (sortedList.isEmpty) return 0.0;
  final int index = (percentile * (sortedList.length - 1)).round();
  return sortedList[index.clamp(0, sortedList.length - 1)];
}

_BucketWindow _thresholdWindowFor(
  String level,
  DifficultyBucketConfig thresholds,
) {
  final List<DifficultyBucketThreshold> buckets = thresholds.buckets;
  for (int i = 0; i < buckets.length; i++) {
    final DifficultyBucketThreshold current = buckets[i];
    if (current.id == level) {
      final double? minExclusive = i == 0 ? null : buckets[i - 1].maxInclusive;
      return _BucketWindow(
        id: current.id,
        minExclusive: minExclusive,
        maxInclusive: current.maxInclusive,
      );
    }
  }
  return _BucketWindow(id: level, minExclusive: null, maxInclusive: null);
}

class _BucketWindow {
  const _BucketWindow({
    required this.id,
    required this.minExclusive,
    required this.maxInclusive,
  });

  final String id;
  final double? minExclusive;
  final double? maxInclusive;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'minExclusive': minExclusive,
    'maxInclusive': maxInclusive,
  };
}

enum _KakuroBenchmarkProfileTier { shipping, experimental }

class _KakuroBenchmarkGateThresholds {
  const _KakuroBenchmarkGateThresholds({
    required this.minSuccessRate,
    required this.maxGenerationP95Ms,
    required this.maxUniquenessSolveP95Ms,
    required this.maxUnknownStatusCount,
    required this.minDifficultyMatchRate,
  });

  final double minSuccessRate;
  final double maxGenerationP95Ms;
  final double maxUniquenessSolveP95Ms;
  final int maxUnknownStatusCount;
  final double minDifficultyMatchRate;

  Map<String, Object?> toJson() => <String, Object?>{
    'minSuccessRate': minSuccessRate,
    'maxGenerationP95Ms': maxGenerationP95Ms,
    'maxUniquenessSolveP95Ms': maxUniquenessSolveP95Ms,
    'maxUnknownStatusCount': maxUnknownStatusCount,
    'minDifficultyMatchRate': minDifficultyMatchRate,
  };
}

class _KakuroBenchmarkProfile {
  const _KakuroBenchmarkProfile({
    required this.name,
    required this.sizeId,
    required this.difficulty,
    required this.tier,
    required this.seedCorpus,
    required this.gateThresholds,
  });

  final String name;
  final String sizeId;
  final String difficulty;
  final _KakuroBenchmarkProfileTier tier;
  final List<String> seedCorpus;
  final _KakuroBenchmarkGateThresholds gateThresholds;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'sizeId': sizeId,
    'difficulty': difficulty,
    'tier': tier.name,
    'corpusSize': seedCorpus.length,
    'gateThresholds': gateThresholds.toJson(),
  };
}

class _KakuroBenchmarkGateResult {
  const _KakuroBenchmarkGateResult({
    required this.enforced,
    required this.passed,
    required this.failures,
  });

  final bool enforced;
  final bool passed;
  final List<String> failures;

  Map<String, Object?> toJson() => <String, Object?>{
    'enforced': enforced,
    'passed': passed,
    'failures': failures,
  };
}

List<String> _buildKakuroSeedCorpus(String profileName, int count) {
  return List<String>.generate(
    count,
    (int i) => 'bench:kakuro_profile:$profileName:$i',
    growable: false,
  );
}

const _KakuroBenchmarkGateThresholds _shippingGateThresholds =
    _KakuroBenchmarkGateThresholds(
      minSuccessRate: 0.95,
      maxGenerationP95Ms: 5500.0,
      maxUniquenessSolveP95Ms: 350.0,
      maxUnknownStatusCount: 0,
      minDifficultyMatchRate: 0.80,
    );

const _KakuroBenchmarkGateThresholds _experimentalGateThresholds =
    _KakuroBenchmarkGateThresholds(
      minSuccessRate: 0.70,
      maxGenerationP95Ms: 8000.0,
      maxUniquenessSolveP95Ms: 900.0,
      maxUnknownStatusCount: 6,
      minDifficultyMatchRate: 0.50,
    );

final Map<String, _KakuroBenchmarkProfile>
_kakuroBenchmarkProfiles = <String, _KakuroBenchmarkProfile>{
  'kakuro_7x7_easy_shipping': _KakuroBenchmarkProfile(
    name: 'kakuro_7x7_easy_shipping',
    sizeId: '7x7',
    difficulty: 'easy',
    tier: _KakuroBenchmarkProfileTier.shipping,
    seedCorpus: const <String>[
      'bench:kakuro_profile:k7_candidate:3',
      'bench:kakuro_profile:k7_candidate:5',
      'bench:kakuro_profile:k7_candidate:6',
      'bench:kakuro_profile:k7_candidate:7',
      'bench:kakuro_profile:k7_candidate:9',
      'bench:kakuro_profile:k7_candidate:11',
      'bench:kakuro_profile:k7_candidate:13',
      'bench:kakuro_profile:k7_candidate:14',
      'bench:kakuro_profile:k7_candidate:15',
      'bench:kakuro_profile:k7_candidate:17',
      'bench:kakuro_profile:k7_candidate:20',
      'bench:kakuro_profile:k7_candidate:22',
      'bench:kakuro_profile:k7_candidate:23',
      'bench:kakuro_profile:k7_candidate:24',
      'bench:kakuro_profile:k7_candidate:27',
      'bench:kakuro_profile:k7_candidate:28',
      'bench:kakuro_profile:k7_candidate:29',
      'bench:kakuro_profile:k7_candidate:31',
      'bench:kakuro_profile:k7_candidate:32',
      'bench:kakuro_profile:k7_candidate:36',
      'bench:kakuro_profile:k7_candidate:38',
      'bench:kakuro_profile:k7_candidate:39',
      'bench:kakuro_profile:k7_candidate:40',
      'bench:kakuro_profile:k7_candidate:43',
    ],
    gateThresholds: _shippingGateThresholds,
  ),
  'kakuro_9x9_medium_experimental': _KakuroBenchmarkProfile(
    name: 'kakuro_9x9_medium_experimental',
    sizeId: '9x9',
    difficulty: 'medium',
    tier: _KakuroBenchmarkProfileTier.experimental,
    seedCorpus: _buildKakuroSeedCorpus('kakuro_9x9_medium_experimental', 24),
    gateThresholds: _experimentalGateThresholds,
  ),
  'kakuro_9x9_hard_experimental': _KakuroBenchmarkProfile(
    name: 'kakuro_9x9_hard_experimental',
    sizeId: '9x9',
    difficulty: 'hard',
    tier: _KakuroBenchmarkProfileTier.experimental,
    seedCorpus: _buildKakuroSeedCorpus('kakuro_9x9_hard_experimental', 24),
    gateThresholds: _experimentalGateThresholds,
  ),
  'kakuro_9x9_expert_experimental': _KakuroBenchmarkProfile(
    name: 'kakuro_9x9_expert_experimental',
    sizeId: '9x9',
    difficulty: 'expert',
    tier: _KakuroBenchmarkProfileTier.experimental,
    seedCorpus: _buildKakuroSeedCorpus('kakuro_9x9_expert_experimental', 24),
    gateThresholds: _experimentalGateThresholds,
  ),
};

_KakuroBenchmarkGateResult _evaluateKakuroGate({
  required _KakuroBenchmarkProfile profile,
  required double successRate,
  required double generationP95Ms,
  required double uniquenessP95Ms,
  required int unknownStatusCount,
  required double difficultyMatchRate,
  required bool enforceExperimentalGate,
}) {
  final bool enforced =
      profile.tier == _KakuroBenchmarkProfileTier.shipping ||
      enforceExperimentalGate;
  final List<String> failures = <String>[];
  if (!enforced) {
    return _KakuroBenchmarkGateResult(
      enforced: false,
      passed: true,
      failures: failures,
    );
  }
  final _KakuroBenchmarkGateThresholds thresholds = profile.gateThresholds;
  if (successRate < thresholds.minSuccessRate) {
    failures.add(
      'successRate ${successRate.toStringAsFixed(3)} < ${thresholds.minSuccessRate.toStringAsFixed(3)}',
    );
  }
  if (generationP95Ms > thresholds.maxGenerationP95Ms) {
    failures.add(
      'generationP95Ms ${generationP95Ms.toStringAsFixed(2)} > ${thresholds.maxGenerationP95Ms.toStringAsFixed(2)}',
    );
  }
  if (uniquenessP95Ms > thresholds.maxUniquenessSolveP95Ms) {
    failures.add(
      'uniquenessP95Ms ${uniquenessP95Ms.toStringAsFixed(2)} > ${thresholds.maxUniquenessSolveP95Ms.toStringAsFixed(2)}',
    );
  }
  if (unknownStatusCount > thresholds.maxUnknownStatusCount) {
    failures.add(
      'unknownStatusCount $unknownStatusCount > ${thresholds.maxUnknownStatusCount}',
    );
  }
  if (difficultyMatchRate < thresholds.minDifficultyMatchRate) {
    failures.add(
      'difficultyMatchRate ${difficultyMatchRate.toStringAsFixed(3)} < ${thresholds.minDifficultyMatchRate.toStringAsFixed(3)}',
    );
  }
  return _KakuroBenchmarkGateResult(
    enforced: true,
    passed: failures.isEmpty,
    failures: failures,
  );
}

/// Parse difficulty string to DifficultyScore.
DifficultyScore _parseDifficulty(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return const DifficultyScore(value: 0.3, level: 'easy');
    case 'medium':
      return const DifficultyScore(value: 0.6, level: 'medium');
    case 'hard':
      return const DifficultyScore(value: 0.9, level: 'hard');
    case 'expert':
      return const DifficultyScore(value: 1.0, level: 'expert');
    default:
      return const DifficultyScore(value: 0.6, level: 'medium');
  }
}

/// Calculate percentile from sorted list.
int _percentile(List<int> sortedList, double percentile) {
  if (sortedList.isEmpty) return 0;
  final index = (percentile * (sortedList.length - 1)).round();
  return sortedList[index.clamp(0, sortedList.length - 1)];
}

/// Result of benchmarking a single engine.
class EngineBenchmarkResult {
  final String engineId;
  final bool success;
  final String? error;
  final double p50Ms;
  final double p95Ms;
  final double p99Ms;
  final double totalTimeMs;
  final int iterations;
  final Map<String, Object?> extras;

  EngineBenchmarkResult({
    required this.engineId,
    required this.success,
    required this.error,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
    required this.totalTimeMs,
    required this.iterations,
    this.extras = const <String, Object?>{},
  });

  Map<String, dynamic> toJson() => {
    'engineId': engineId,
    'success': success,
    'error': error,
    'p50Ms': p50Ms,
    'p95Ms': p95Ms,
    'p99Ms': p99Ms,
    'totalTimeMs': totalTimeMs,
    'iterations': iterations,
    if (extras.isNotEmpty) 'extras': extras,
  };

  factory EngineBenchmarkResult.fromJson(Map<String, dynamic> json) =>
      EngineBenchmarkResult(
        engineId: json['engineId'] as String,
        success: json['success'] as bool,
        error: json['error'] as String?,
        p50Ms: (json['p50Ms'] as num?)?.toDouble() ?? 0,
        p95Ms: (json['p95Ms'] as num).toDouble(),
        p99Ms: (json['p99Ms'] as num).toDouble(),
        totalTimeMs: (json['totalTimeMs'] as num).toDouble(),
        iterations: json['iterations'] as int,
        extras: Map<String, Object?>.from(json['extras'] as Map? ?? const {}),
      );
}
