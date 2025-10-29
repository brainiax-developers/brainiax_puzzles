import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../models/puzzle_type.dart' as app;
import '../services/puzzle_registry.dart';
import '../services/seed_service.dart';
import 'engine_provider.dart';

/// Phase-2 service level agreement for puzzle generation latency.
const Duration puzzleGenerationPhase2Sla = Duration(milliseconds: 100);

/// Riverpod controller responsible for generating puzzles asynchronously.
final puzzleGenerationControllerProvider =
    AsyncNotifierProvider<PuzzleGenerationController, core.GeneratedPuzzle<dynamic>?>(
  PuzzleGenerationController.new,
);

/// Handles puzzle generation lifecycle including cancellation and state transitions.
class PuzzleGenerationController extends AsyncNotifier<core.GeneratedPuzzle<dynamic>?> {
  Future<void>? _activeOperation;
  int _generationToken = 0;

  @override
  Future<core.GeneratedPuzzle<dynamic>?> build() async {
    return null;
  }

  /// Generate a new puzzle for the provided [puzzleType] and [difficulty].
  ///
  /// The method exposes loading, success, and error states through [state].
  /// If another generation is already running it will be cancelled first.
  Future<core.GeneratedPuzzle<dynamic>> generate({
    required app.PuzzleType puzzleType,
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

    // Set loading state
    state = const AsyncValue.loading();

    final resolvedSize = size != null ? _parseSize(size) : _defaultSizeFor(puzzleType);
    final difficultyScore = _parseDifficulty(difficulty);

    final token = ++_generationToken;

    try {
      // Some engines (e.g., Kakuro) may fail for specific seeds; retry with fresh seeds a few times
      const int maxAttempts = 3;
      Object? lastError;
      StackTrace? lastStack;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        final attemptSeed = seed ?? SeedService().generateRandomSeed(puzzleType.key);
        try {
          final generated = engine.generate(
            seedStr: attemptSeed,
            seed64: attemptSeed.hashCode,
            size: resolvedSize,
            difficulty: difficultyScore,
          );
          if (token == _generationToken) {
            state = AsyncValue.data(generated);
          }
          return generated;
        } catch (e, st) {
          lastError = e;
          lastStack = st;
          // Try next attempt with a new seed
          if (attempt == maxAttempts) break;
          // brief microtask yield to keep UI responsive
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      // If we get here, all attempts failed
      if (token == _generationToken) {
        state = AsyncValue.error(lastError ?? StateError('Generation failed'), lastStack ?? StackTrace.current);
      }
      throw lastError ?? StateError('Generation failed');
    } catch (err, stackTrace) {
      if (token == _generationToken) {
        state = AsyncValue.error(err, stackTrace);
      }
      rethrow;
    }
  }

  /// Cancel the currently running generation (if any) and reset state.
  Future<void> cancelGeneration() async {
    _generationToken++;
    _activeOperation = null;
    state = const AsyncValue.data(null);
  }

  /// Whether the controller currently has an in-flight generation request.
  bool get isGenerating => state.isLoading;

  core.SizeOpt _defaultSizeFor(app.PuzzleType puzzleType) {
    final metadata = PuzzleRegistry().getMetadata(puzzleType);
    if (metadata != null && metadata.supportedSizes.isNotEmpty) {
      try {
        return _parseSize(metadata.supportedSizes.first);
      } catch (_) {
        // Continue with fallback sizes if parsing fails.
      }
    }

    switch (puzzleType) {
      case app.PuzzleType.sudokuClassic:
        return const core.SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
      case app.PuzzleType.nonogramMono:
        return const core.SizeOpt(id: '10x10', description: '10x10', width: 10, height: 10);
      case app.PuzzleType.kakuroClassic:
        return const core.SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
      case app.PuzzleType.slitherlinkLoop:
        return const core.SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7);
      case app.PuzzleType.mathdokuClassic:
        return const core.SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6);
      case app.PuzzleType.futoshikiClassic:
        return const core.SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6);
      case app.PuzzleType.takuzuBinary:
        return const core.SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8);
    }
  }

  core.SizeOpt _parseSize(String size) {
    final parts = size.split('x');
    if (parts.length != 2) {
      throw ArgumentError('Invalid size format: $size');
    }
    final width = int.parse(parts[0]);
    final height = int.parse(parts[1]);

    return core.SizeOpt(
      id: size,
      description: size,
      width: width,
      height: height,
    );
  }

  core.DifficultyScore _parseDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const core.DifficultyScore(value: 0.3, level: 'easy');
      case 'medium':
        return const core.DifficultyScore(value: 0.6, level: 'medium');
      case 'hard':
        return const core.DifficultyScore(value: 0.9, level: 'hard');
      case 'expert':
        return const core.DifficultyScore(value: 1.2, level: 'expert');
      default:
        return const core.DifficultyScore(value: 0.6, level: 'medium');
    }
  }
}