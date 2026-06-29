import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

const Duration defaultPuzzleGenerationTimeout = Duration(seconds: 2);

const Duration killerQueensPuzzleGenerationTimeout = Duration(seconds: 12);

Duration puzzleGenerationTimeoutFor({
  required String engineId,
  String? difficulty,
  bool preload = false,
}) {
  switch (engineId) {

    case 'killer_queens':
      return killerQueensPuzzleGenerationTimeout;
    case 'kakuro':
      // Kakuro solver DFS can hit 2+ seconds on the very first JIT compilation run.
      // Large 9x9 grids may require extensive uniqueness checking across multiple attempts.
      return const Duration(seconds: 12);
    default:
      return defaultPuzzleGenerationTimeout;
  }
}

core.SizeOpt killerQueensAppSizeForDifficulty(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'easy':
      return const core.SizeOpt(
        id: '6x6',
        description: '6x6',
        width: 6,
        height: 6,
      );
    case 'medium':
      return const core.SizeOpt(
        id: '8x8',
        description: '8x8',
        width: 8,
        height: 8,
      );
    case 'hard':
      return const core.SizeOpt(
        id: '10x10',
        description: '10x10',
        width: 10,
        height: 10,
      );
    case 'expert':
      // TODO(killer-queens): Restore 12x12 Expert in the app after the
      // uniqueness-checked generator meets mobile p95 reliably.
      return const core.SizeOpt(
        id: '10x10',
        description: '10x10',
        width: 10,
        height: 10,
      );
    default:
      return const core.SizeOpt(
        id: '8x8',
        description: '8x8',
        width: 8,
        height: 8,
      );
  }
}

/// Input for puzzle generation that can be sent to a worker implementation.
class PuzzleGenerationRequest {
  const PuzzleGenerationRequest({
    required this.engineId,
    required this.seedStr,
    required this.seed64,
    required this.size,
    required this.difficulty,
  });

  final String engineId;
  final String seedStr;
  final int seed64;
  final core.SizeOpt size;
  final core.DifficultyScore difficulty;
}

/// Timeout raised by a generation worker.
///
/// [computationCancelled] is false for the current isolate-per-request worker:
/// Dart can stop waiting for [Isolate.run], but it cannot cancel that isolate
/// computation through [Future.timeout].
class PuzzleGenerationTimeoutException extends TimeoutException {
  PuzzleGenerationTimeoutException(
    super.message,
    super.duration, {
    required this.computationCancelled,
  });

  final bool computationCancelled;

  @override
  String toString() {
    return 'PuzzleGenerationTimeoutException: $message '
        '(duration: $duration, computationCancelled: $computationCancelled)';
  }
}

/// Abstraction for puzzle generation that can later be backed by a long-lived
/// worker isolate without changing callers.
abstract interface class PuzzleGenerationWorker {
  Future<core.GeneratedPuzzle<dynamic>> generate(
    PuzzleGenerationRequest request, {
    Duration? timeout,
  });
}

/// Worker implementation that spawns a background isolate for each generation.
class IsolatePuzzleGenerationWorker implements PuzzleGenerationWorker {
  const IsolatePuzzleGenerationWorker();

  @override
  Future<core.GeneratedPuzzle<dynamic>> generate(
    PuzzleGenerationRequest request, {
    Duration? timeout,
  }) {
    final generation = generatePuzzleIsolated(
      engineId: request.engineId,
      seedStr: request.seedStr,
      seed64: request.seed64,
      size: request.size,
      difficulty: request.difficulty,
    );
    if (timeout == null) {
      return generation;
    }
    return generation.timeout(
      timeout,
      onTimeout: () {
        throw PuzzleGenerationTimeoutException(
          'Puzzle generation timed out for ${request.engineId}; '
          'the isolate computation may still complete later.',
          timeout,
          computationCancelled: false,
        );
      },
    );
  }
}

final puzzleGenerationWorkerProvider = Provider<PuzzleGenerationWorker>((ref) {
  return const IsolatePuzzleGenerationWorker();
});

/// Run a CPU-heavy puzzle generation on a background isolate to keep UI responsive.
Future<core.GeneratedPuzzle<dynamic>> generatePuzzleIsolated({
  required String engineId,
  required String seedStr,
  required int seed64,
  required core.SizeOpt size,
  required core.DifficultyScore difficulty,
}) async {
  // Use Isolate.run (Dart 3) so we can return complex objects without manual
  // SendPort marshalling.
  return await Isolate.run(() {
    final core.PipelinePuzzleEngine<dynamic, dynamic> engine = _createEngine(
      engineId,
    );
    return engine.generate(
      seedStr: seedStr,
      seed64: seed64,
      size: size,
      difficulty: difficulty,
    );
  });
}

core.PipelinePuzzleEngine<dynamic, dynamic> _createEngine(String engineId) {
  switch (engineId) {
    case 'sudoku_classic':
      return core.SudokuEngine();
    case 'nonogram_mono':
      return core.NonogramEngine();

    case 'slitherlink_loop':
      return core.SlitherlinkEngine();
    case 'mathdoku_classic':
      return core.MathdokuEngine();
    case 'killer_queens':
      return core.KillerQueensEngine();
    case 'takuzu_binary':
      return core.TakuzuEngine();
    case 'kakuro':
      return core.KakuroEngine();
    default:
      // Fallback to a stub engine for unknown types to avoid crashes.
      return core.StubPuzzleEngine(engineId: engineId);
  }
}
