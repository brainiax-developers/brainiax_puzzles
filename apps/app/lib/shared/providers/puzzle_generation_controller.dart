import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart';

import '../models/puzzle_type.dart';
import '../services/puzzle_registry.dart';
import '../services/seed_service.dart';
import 'engine_provider.dart';

/// Phase-2 service level agreement for puzzle generation latency.
const Duration puzzleGenerationPhase2Sla = Duration(milliseconds: 150);

/// Riverpod controller responsible for generating puzzles asynchronously.
final puzzleGenerationControllerProvider =
    AutoDisposeAsyncNotifierProvider<PuzzleGenerationController, GeneratedPuzzle<dynamic>?>(
  PuzzleGenerationController.new,
);

/// Handles puzzle generation lifecycle including cancellation and state transitions.
class PuzzleGenerationController extends AutoDisposeAsyncNotifier<GeneratedPuzzle<dynamic>?> {
  CancelableOperation<GeneratedPuzzle<dynamic>>? _activeOperation;
  int _generationToken = 0;

  @override
  GeneratedPuzzle<dynamic>? build() {
    ref.onDispose(() {
      _activeOperation?.cancel();
    });
    return null;
  }

  /// Generate a new puzzle for the provided [puzzleType] and [difficulty].
  ///
  /// The method exposes loading, success, and error states through [state].
  /// If another generation is already running it will be cancelled first.
  Future<GeneratedPuzzle<dynamic>> generate({
    required PuzzleType puzzleType,
    required String difficulty,
    String? seed,
    String? size,
  }) async {
    await cancelGeneration();

    final engine = ref.read(engineProvider(puzzleType.key));
    if (engine == null) {
      final error = StateError('Puzzle engine not registered for ${puzzleType.key}');
      state = AsyncValue.error(error, StackTrace.current);
      throw error;
    }

    state = const AsyncValue.loading();

    final resolvedSeed = seed ?? SeedService().generateRandomSeed(puzzleType.key);
    final resolvedSize = size != null ? _parseSize(size) : _defaultSizeFor(puzzleType);
    final difficultyScore = _parseDifficulty(difficulty);

    final token = ++_generationToken;
    final completer = CancelableCompleter<GeneratedPuzzle<dynamic>>(onCancel: () {});
    _activeOperation = completer.operation;

    Future<void>(() {
      try {
        final generated = engine.generate(
          seedStr: resolvedSeed,
          seed64: resolvedSeed.hashCode,
          size: resolvedSize,
          difficulty: difficultyScore,
        );
        if (!completer.isCanceled) {
          completer.complete(generated);
        }
      } catch (err, stackTrace) {
        if (!completer.isCanceled) {
          completer.completeError(err, stackTrace);
        }
      }
    });

    try {
      final puzzle = await _activeOperation!.value;
      if (token == _generationToken && !_activeOperation!.isCanceled) {
        state = AsyncValue.data(puzzle);
      }
      return puzzle;
    } on OperationCanceledError {
      if (token == _generationToken) {
        state = const AsyncValue.data(null);
      }
      rethrow;
    } catch (err, stackTrace) {
      if (token == _generationToken) {
        state = AsyncValue.error(err, stackTrace);
      }
      rethrow;
    } finally {
      if (token == _generationToken) {
        _activeOperation = null;
      }
    }
  }

  /// Cancel the currently running generation (if any) and reset state.
  Future<void> cancelGeneration() async {
    _generationToken++;
    final operation = _activeOperation;
    _activeOperation = null;
    if (operation != null) {
      await operation.cancel();
    }
    state = const AsyncValue.data(null);
  }

  /// Whether the controller currently has an in-flight generation request.
  bool get isGenerating => state.isLoading;

  SizeOpt _defaultSizeFor(PuzzleType puzzleType) {
    final metadata = PuzzleRegistry().getMetadata(puzzleType);
    if (metadata != null && metadata.supportedSizes.isNotEmpty) {
      try {
        return _parseSize(metadata.supportedSizes.first);
      } catch (_) {
        // Continue with fallback sizes if parsing fails.
      }
    }

    switch (puzzleType) {
      case PuzzleType.sudokuClassic:
        return const SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
      case PuzzleType.nonogramMono:
        return const SizeOpt(id: '10x10', description: '10x10', width: 10, height: 10);
      case PuzzleType.kakuroClassic:
        return const SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8);
      case PuzzleType.slitherlinkLoop:
        return const SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7);
      case PuzzleType.mathdokuClassic:
        return const SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6);
      case PuzzleType.futoshikiClassic:
        return const SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6);
      case PuzzleType.takuzuBinary:
        return const SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8);
    }
  }

  SizeOpt _parseSize(String size) {
    final parts = size.split('x');
    if (parts.length != 2) {
      throw ArgumentError('Invalid size format: $size');
    }
    final width = int.parse(parts[0]);
    final height = int.parse(parts[1]);

    return SizeOpt(
      id: size,
      description: size,
      width: width,
      height: height,
    );
  }

  DifficultyScore _parseDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const DifficultyScore(value: 0.3, level: 'easy');
      case 'medium':
        return const DifficultyScore(value: 0.6, level: 'medium');
      case 'hard':
        return const DifficultyScore(value: 0.9, level: 'hard');
      case 'expert':
        return const DifficultyScore(value: 1.2, level: 'expert');
      default:
        return const DifficultyScore(value: 0.6, level: 'medium');
    }
  }
}
