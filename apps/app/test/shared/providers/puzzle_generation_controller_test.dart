import 'package:async/async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import 'package:app/shared/models/puzzle_type.dart';
import 'package:app/shared/providers/puzzle_generation_controller.dart';

void main() {
  const iterationsForBenchmark = 30;

  late ProviderContainer container;

  setUp(() {
    final registry = core.EngineRegistry();
    registry.clear();
    registry.register(core.StubPuzzleEngine(engineId: PuzzleType.sudokuClassic.key));
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    core.EngineRegistry().clear();
  });

  test('generates puzzles and updates state to data', () async {
    final controller = container.read(puzzleGenerationControllerProvider.notifier);

    final future = controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
    );

    expect(controller.state.isLoading, isTrue);

    final puzzle = await future;
    expect(puzzle, isNotNull);
    expect(controller.state.hasValue, isTrue);
    expect(controller.state.value, equals(puzzle));
  });

  test('emits error when engine is unavailable', () async {
    core.EngineRegistry().clear();
    final controller = container.read(puzzleGenerationControllerProvider.notifier);

    expect(
      () => controller.generate(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'medium',
      ),
      throwsA(isA<StateError>()),
    );
    expect(controller.state.hasError, isTrue);
  });

  test('cancelGeneration stops updates and returns canceled error', () async {
    final controller = container.read(puzzleGenerationControllerProvider.notifier);

    final future = controller.generate(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'medium',
    );

    await controller.cancelGeneration();

    expect(controller.state.value, isNull);
    await expectLater(future, throwsA(isA<OperationCanceledError>()));
  });

  test('meets phase-2 puzzle generation SLA (p95)', () async {
    final controller = container.read(puzzleGenerationControllerProvider.notifier);
    final samples = <int>[];

    for (int i = 0; i < iterationsForBenchmark; i++) {
      final watch = Stopwatch()..start();
      await controller.generate(
        puzzleType: PuzzleType.sudokuClassic,
        difficulty: 'medium',
      );
      watch.stop();
      samples.add(watch.elapsedMicroseconds);
    }

    samples.sort();
    final p95Index = ((samples.length - 1) * 95) ~/ 100;
    final p95Duration = Duration(microseconds: samples[p95Index]);

    expect(p95Duration <= puzzleGenerationPhase2Sla, isTrue,
        reason:
            'Puzzle generation p95 ${p95Duration.inMilliseconds}ms exceeds SLA ${puzzleGenerationPhase2Sla.inMilliseconds}ms');
  });
}
