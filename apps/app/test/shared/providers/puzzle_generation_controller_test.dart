import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import 'package:app/shared/crash/crash_reporting_providers.dart';
import 'package:app/shared/crash/crash_reporting_service.dart';
import 'package:app/shared/models/puzzle_type.dart';
import 'package:app/shared/providers/puzzle_generation_controller.dart';
import 'package:app/shared/services/generation_isolate.dart';
import 'package:app/shared/services/slitherlink_on_demand_service.dart';

void main() {
  const iterationsForBenchmark = 30;

  late ProviderContainer container;

  setUp(() {
    final registry = core.EngineRegistry();
    registry.clear();
    registry.register(
      core.StubPuzzleEngine(engineId: PuzzleType.sudokuClassic.key),
    );
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    core.EngineRegistry().clear();
  });

  test('generates puzzles and updates state to data', () async {
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );

    final future = controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.isLoading, isTrue);

    final puzzle = await future;
    expect(puzzle, isNotNull);
    expect(controller.state.hasValue, isTrue);
    expect(controller.state.value, equals(puzzle));
  });

  test('emits error when engine is unavailable', () async {
    core.EngineRegistry().clear();
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );

    await expectLater(
      controller.generate(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'medium',
      ),
      throwsA(isA<StateError>()),
    );
    expect(controller.state.hasError, isTrue);
  });

  test('cancelGeneration stops updates and resets state', () async {
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );

    final future = controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
    );

    await controller.cancelGeneration();

    expect(controller.state.value, isNull);
    // The future should still complete since we simplified the cancellation
    final puzzle = await future;
    expect(puzzle, isNotNull);
  });

  test('stale generation results do not update state', () async {
    final worker = _QueuedPuzzleGenerationWorker();
    final firstCompleter = Completer<core.GeneratedPuzzle<dynamic>>();
    final secondCompleter = Completer<core.GeneratedPuzzle<dynamic>>();
    worker.queue(firstCompleter.future);
    worker.queue(secondCompleter.future);
    container.dispose();
    container = ProviderContainer(
      overrides: [puzzleGenerationWorkerProvider.overrideWithValue(worker)],
    );
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );

    final firstFuture = controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
      seed: 'first',
    );
    await Future<void>.delayed(Duration.zero);

    final secondFuture = controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
      seed: 'second',
    );
    await Future<void>.delayed(Duration.zero);

    final secondPuzzle = _stubPuzzle(
      seedStr: 'second',
      seed64: core.Seed.fromString('second'),
    );
    secondCompleter.complete(secondPuzzle);
    final resolvedSecond = await secondFuture;
    expect(resolvedSecond.meta.seedStr, equals(secondPuzzle.meta.seedStr));
    expect(
      controller.state.value?.meta.seedStr,
      equals(secondPuzzle.meta.seedStr),
    );

    final firstPuzzle = _stubPuzzle(
      seedStr: 'first',
      seed64: core.Seed.fromString('first'),
    );
    firstCompleter.complete(firstPuzzle);
    final resolvedFirst = await firstFuture;
    expect(resolvedFirst.meta.seedStr, equals(firstPuzzle.meta.seedStr));
    expect(
      controller.state.value?.meta.seedStr,
      equals(secondPuzzle.meta.seedStr),
    );
  });

  test('retries mismatched generated difficulty before returning', () async {
    final worker = _QueuedPuzzleGenerationWorker();
    worker.queue(
      Future<core.GeneratedPuzzle<dynamic>>.value(
        _stubPuzzle(
          seedStr: 'difficulty-seed',
          seed64: core.Seed.fromString('difficulty-seed'),
          difficulty: 'hard',
        ),
      ),
    );
    worker.queue(
      Future<core.GeneratedPuzzle<dynamic>>.value(
        _stubPuzzle(
          seedStr: 'difficulty-seed#attempt2',
          seed64: core.Seed.fromString('difficulty-seed#attempt2'),
          difficulty: 'easy',
        ),
      ),
    );
    container.dispose();
    container = ProviderContainer(
      overrides: [puzzleGenerationWorkerProvider.overrideWithValue(worker)],
    );
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );

    final puzzle = await controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      seed: 'difficulty-seed',
    );

    expect(worker.requests, hasLength(2));
    expect(worker.requests.first.difficulty.level, equals('easy'));
    expect(puzzle.meta.difficulty.level, equals('easy'));
    expect(puzzle.telemetry?.extras['requestedDifficulty'], equals('easy'));
    expect(puzzle.telemetry?.extras['difficultyMismatch'], isFalse);
    expect(controller.state.value?.meta.difficulty.level, equals('easy'));
  });

  test(
    'preserves measured difficulty after bounded mismatch retries',
    () async {
      final worker = _QueuedPuzzleGenerationWorker();
      for (int attempt = 1; attempt <= 3; attempt++) {
        final seed = attempt == 1 ? 'all-hard' : 'all-hard#attempt$attempt';
        worker.queue(
          Future<core.GeneratedPuzzle<dynamic>>.value(
            _stubPuzzle(
              seedStr: seed,
              seed64: core.Seed.fromString(seed),
              difficulty: 'hard',
            ),
          ),
        );
      }
      container.dispose();
      container = ProviderContainer(
        overrides: [puzzleGenerationWorkerProvider.overrideWithValue(worker)],
      );
      final controller = container.read(
        puzzleGenerationControllerProvider.notifier,
      );

      final puzzle = await controller.generate(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'easy',
        seed: 'all-hard',
      );

      expect(worker.requests, hasLength(3));
      expect(puzzle.meta.difficulty.level, equals('hard'));
      expect(puzzle.telemetry?.extras['requestedDifficulty'], equals('easy'));
      expect(puzzle.telemetry?.extras['measuredDifficulty'], equals('hard'));
      expect(puzzle.telemetry?.extras['displayedDifficulty'], equals('hard'));
      expect(puzzle.telemetry?.extras['difficultyMismatch'], isTrue);
      expect(puzzle.telemetry?.extras['difficultyFallback'], isTrue);
      expect(
        puzzle.telemetry?.extras['difficultyFallbackReason'],
        equals('controller_best_effort_after_mismatch_retries'),
      );
    },
  );



  test('worker timeout errors surface cleanly', () async {
    final timeout = PuzzleGenerationTimeoutException(
      'test timeout',
      const Duration(milliseconds: 1),
      computationCancelled: false,
    );
    final worker = _QueuedPuzzleGenerationWorker();
    for (int i = 0; i < 3; i++) {
      worker.queueError(timeout);
    }
    container.dispose();
    container = ProviderContainer(
      overrides: [puzzleGenerationWorkerProvider.overrideWithValue(worker)],
    );
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );

    await expectLater(
      controller.generate(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'medium',
      ),
      throwsA(
        isA<PuzzleGenerationTimeoutException>().having(
          (error) => error.computationCancelled,
          'computationCancelled',
          isFalse,
        ),
      ),
    );
    expect(controller.state.hasError, isTrue);
    expect(controller.state.error, same(timeout));
  });

  test(
    'reports non-fatal generation failures through crash reporting',
    () async {
      final worker = _QueuedPuzzleGenerationWorker();
      final _RecordingCrashReportingService crashReporting =
          _RecordingCrashReportingService();
      worker.queueError(StateError('board={"cells":[1,2,3]}'));
      worker.queueError(StateError('board={"cells":[1,2,3]}'));
      worker.queueError(StateError('board={"cells":[1,2,3]}'));
      container.dispose();
      container = ProviderContainer(
        overrides: [
          puzzleGenerationWorkerProvider.overrideWithValue(worker),
          crashReportingServiceProvider.overrideWithValue(crashReporting),
        ],
      );
      final controller = container.read(
        puzzleGenerationControllerProvider.notifier,
      );

      await expectLater(
        controller.generate(
          puzzleType: PuzzleType.sudokuClassic,
          difficulty: 'medium',
        ),
        throwsA(isA<StateError>()),
      );

      expect(crashReporting.calls, hasLength(1));
      expect(crashReporting.calls.single.reason, 'puzzle_generation_failure');
      expect(
        crashReporting.calls.single.context,
        containsPair('puzzleType', PuzzleType.sudokuClassic.key),
      );
      expect(
        crashReporting.calls.single.context,
        containsPair('difficulty', 'medium'),
      );
      expect(crashReporting.calls.single.context.containsKey('board'), isFalse);
    },
  );

  test(
    'passes the resolved seed into Slitherlink on-demand generation',
    () async {
      core.EngineRegistry().register(core.SlitherlinkEngine());
      final service = _RecordingSlitherlinkOnDemandService(
        result: _slitherlinkPuzzle(
          seedStr: 'seed:slitherlink',
          seed64: core.Seed.fromString('seed:slitherlink'),
        ),
      );
      container.dispose();
      container = ProviderContainer(
        overrides: [slitherlinkOnDemandProvider.overrideWithValue(service)],
      );
      final controller = container.read(
        puzzleGenerationControllerProvider.notifier,
      );

      final puzzle = await controller.generate(
        puzzleType: PuzzleType.slitherlinkLoop,
        difficulty: 'hard',
        size: '7x5',
        seed: 'seed:slitherlink',
      );

      expect(service.lastDifficulty, equals('hard'));
      expect(service.lastWidth, equals(7));
      expect(service.lastHeight, equals(5));
      expect(service.lastSeed, equals('seed:slitherlink'));
      expect(puzzle.meta.seedStr, equals('seed:slitherlink'));
      expect(
        puzzle.meta.seed64,
        equals(core.Seed.fromString('seed:slitherlink')),
      );
      expect(puzzle.telemetry?.extras['requestedDifficulty'], equals('hard'));
      expect(puzzle.telemetry?.extras['displayedDifficulty'], equals('hard'));
      expect(puzzle.telemetry?.extras['difficultyMismatch'], isFalse);
    },
  );

  test('meets phase-2 puzzle generation SLA (p95)', () async {
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );
    final samples = <int>[];

    for (int i = 0; i < iterationsForBenchmark; i++) {
      final watch = Stopwatch()..start();
      await controller.generate(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'hard',
      );
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
    }

    samples.sort();
    final p95Index = ((samples.length - 1) * 95) ~/ 100;
    final p95Duration = Duration(microseconds: samples[p95Index]);

    expect(
      p95Duration <= puzzleGenerationPhase2Sla,
      isTrue,
      reason:
          'Puzzle generation p95 ${p95Duration.inMilliseconds}ms exceeds SLA ${puzzleGenerationPhase2Sla.inMilliseconds}ms',
    );
  });



  test('uses app-safe Killer Queens Expert profile and timeout', () async {
    core.EngineRegistry().register(
      core.StubPuzzleEngine(engineId: PuzzleType.killerQueens.key),
    );
    final worker = _QueuedPuzzleGenerationWorker();
    final puzzle = _stubPuzzle(
      engineId: PuzzleType.killerQueens.key,
      seedStr: 'killer-queens-expert',
      seed64: core.Seed.fromString('killer-queens-expert'),
      difficulty: 'expert',
    );
    worker.queue(Future<core.GeneratedPuzzle<dynamic>>.value(puzzle));
    container.dispose();
    container = ProviderContainer(
      overrides: [puzzleGenerationWorkerProvider.overrideWithValue(worker)],
    );
    final controller = container.read(
      puzzleGenerationControllerProvider.notifier,
    );

    await controller.generate(
      puzzleType: PuzzleType.killerQueens,
      difficulty: 'expert',
      size: '12x12',
      seed: 'killer-queens-expert',
    );

    expect(worker.requests.single.size.id, equals('10x10'));
    expect(worker.requests.single.difficulty.level, equals('expert'));
    expect(worker.timeouts.single, equals(killerQueensPuzzleGenerationTimeout));
  });
}

class _QueuedPuzzleGenerationWorker implements PuzzleGenerationWorker {
  final List<Future<core.GeneratedPuzzle<dynamic>> Function()> _results = [];
  final List<PuzzleGenerationRequest> requests = <PuzzleGenerationRequest>[];
  final List<Duration?> timeouts = <Duration?>[];

  void queue(Future<core.GeneratedPuzzle<dynamic>> result) {
    _results.add(() => result);
  }

  void queueError(Object error) {
    _results.add(() => Future<core.GeneratedPuzzle<dynamic>>.error(error));
  }

  @override
  Future<core.GeneratedPuzzle<dynamic>> generate(
    PuzzleGenerationRequest request, {
    Duration? timeout,
  }) {
    requests.add(request);
    timeouts.add(timeout);
    if (_results.isEmpty) {
      return Future<core.GeneratedPuzzle<dynamic>>.error(
        StateError('No queued generation result'),
      );
    }
    return _results.removeAt(0)();
  }
}

core.GeneratedPuzzle<dynamic> _stubPuzzle({
  String engineId = '',
  required String seedStr,
  required int seed64,
  String difficulty = 'medium',
}) {
  const size = core.SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
  final difficultyScore = switch (difficulty) {
    'easy' => const core.DifficultyScore(value: 0.3, level: 'easy'),
    'hard' => const core.DifficultyScore(value: 0.9, level: 'hard'),
    'expert' => const core.DifficultyScore(value: 1.2, level: 'expert'),
    _ => const core.DifficultyScore(value: 0.6, level: 'medium'),
  };
  return core.GeneratedPuzzle<core.StubPuzzleState>(
    state: core.StubPuzzleState(
      id: seedStr,
      data: <String, dynamic>{
        'engineId': engineId.isEmpty ? PuzzleType.sudokuClassic.key : engineId,
      },
    ),
    meta: core.PuzzleMetadata(
      engineVersion: 'test',
      rngId: core.SeededRng.rngId,
      size: size,
      difficulty: difficultyScore,
      seedStr: seedStr,
      seed64: seed64,
    ),
    telemetry: core.GenerationTelemetry(
      difficulty: core.DifficultyTelemetry(
        rawScore: difficultyScore.value,
        bucket: difficultyScore.level,
        metrics: const <String, num>{},
      ),
      extras: const <String, Object?>{},
    ),
  );
}

core.GeneratedPuzzle<core.SlitherlinkBoard> _slitherlinkPuzzle({
  required String seedStr,
  required int seed64,
}) {
  const size = core.SizeOpt(id: '7x5', description: '7x5', width: 7, height: 5);
  const difficulty = core.DifficultyScore(value: 0.9, level: 'hard');
  final board = core.SlitherlinkBoard.empty(
    width: size.width,
    height: size.height,
    clues: List<int?>.filled(size.width * size.height, null),
  );
  return core.GeneratedPuzzle<core.SlitherlinkBoard>(
    state: board,
    meta: core.PuzzleMetadata(
      engineVersion: 'test',
      rngId: core.SeededRng.rngId,
      size: size,
      difficulty: difficulty,
      seedStr: seedStr,
      seed64: seed64,
    ),
    telemetry: core.GenerationTelemetry(
      difficulty: core.DifficultyTelemetry(
        rawScore: difficulty.value,
        bucket: difficulty.level,
        metrics: const <String, num>{},
      ),
      extras: const <String, Object?>{},
    ),
  );
}

class _RecordingSlitherlinkOnDemandService extends SlitherlinkOnDemandService {
  _RecordingSlitherlinkOnDemandService({required this.result});

  final core.GeneratedPuzzle<core.SlitherlinkBoard> result;
  String? lastDifficulty;
  int? lastWidth;
  int? lastHeight;
  String? lastSeed;

  @override
  Future<core.GeneratedPuzzle<core.SlitherlinkBoard>> nextPuzzle({
    required String difficulty,
    required int width,
    required int height,
    required String seed,
    Duration timeBudget = const Duration(milliseconds: 350),
  }) async {
    lastDifficulty = difficulty;
    lastWidth = width;
    lastHeight = height;
    lastSeed = seed;
    return result;
  }
}

class _RecordingCrashReportingService implements CrashReportingService {
  final List<_CrashReportingCall> calls = <_CrashReportingCall>[];

  @override
  Future<void> reportNonFatal({
    required String reason,
    required Object error,
    required StackTrace stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    calls.add(
      _CrashReportingCall(
        reason: reason,
        error: error,
        stackTrace: stackTrace,
        context: Map<String, Object?>.from(context),
      ),
    );
  }
}

class _CrashReportingCall {
  const _CrashReportingCall({
    required this.reason,
    required this.error,
    required this.stackTrace,
    required this.context,
  });

  final String reason;
  final Object error;
  final StackTrace stackTrace;
  final Map<String, Object?> context;
}
