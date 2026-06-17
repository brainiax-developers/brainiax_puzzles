import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;

import '../models/puzzle_type.dart' as app;
import '../config/app_environment.dart';
import '../services/puzzle_registry.dart';
import '../services/seed_service.dart';
import 'engine_provider.dart';
import '../services/generation_isolate.dart';
import '../services/slitherlink_on_demand_service.dart';

/// Phase-2 service level agreement for puzzle generation latency.
const Duration puzzleGenerationPhase2Sla = Duration(milliseconds: 100);
const int _maxGenerationAttempts = 3;

/// Riverpod controller responsible for generating puzzles asynchronously.
final puzzleGenerationControllerProvider =
    AsyncNotifierProvider<
      PuzzleGenerationController,
      core.GeneratedPuzzle<dynamic>?
    >(PuzzleGenerationController.new);

/// Handles puzzle generation lifecycle including cancellation and state transitions.
class PuzzleGenerationController
    extends AsyncNotifier<core.GeneratedPuzzle<dynamic>?> {
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
    final Stopwatch stopwatch = Stopwatch()..start();

    final engine = ref.read(engineProvider(puzzleType.key));
    if (engine == null) {
      final error = StateError(
        'Puzzle engine not registered for ${puzzleType.key}',
      );
      state = AsyncValue.error(error, StackTrace.current);
      throw error;
    }

    // Set loading state
    state = const AsyncValue.loading();

    final resolvedSize = puzzleType == app.PuzzleType.killerQueens
        ? killerQueensAppSizeForDifficulty(difficulty)
        : size != null
        ? _parseSize(size)
        : _getSizeFor(puzzleType, difficulty);
    final difficultyScore = _parseDifficulty(difficulty);
    _assertProfileAllowedForProduction(
      puzzleType: puzzleType,
      size: resolvedSize,
      difficulty: difficultyScore.level,
    );

    final token = ++_generationToken;

    try {
      if (puzzleType == app.PuzzleType.slitherlinkLoop) {
        final String resolvedSeed =
            seed ?? SeedService().generateRandomSeed(puzzleType.key);
        final core.GeneratedPuzzle<dynamic> generated =
            await _generateSlitherlinkOnDemand(
              difficulty: difficulty,
              size: resolvedSize,
              seed: resolvedSeed,
            );
        if (kDebugMode) {
          debugPrint(
            '[Generation][Success] type=${puzzleType.key} '
            'difficulty=$difficulty size=${resolvedSize.id} '
            'seed=$resolvedSeed elapsedMs=${stopwatch.elapsedMilliseconds}',
          );
        }
        if (token == _generationToken) {
          state = AsyncValue.data(generated);
        }
        return generated;
      }
      // Retry with deterministic sub-seeds derived from one base seed.
      final String baseSeed =
          seed ?? SeedService().generateRandomSeed(puzzleType.key);
      Object? lastError;
      StackTrace? lastStack;
      for (int attempt = 1; attempt <= _maxGenerationAttempts; attempt++) {
        final String attemptSeed = _seedForAttempt(baseSeed, attempt);
        final Duration attemptTimeout = _attemptTimeoutFor(
          puzzleType: puzzleType,
          elapsed: stopwatch.elapsed,
        );
        if (attemptTimeout <= Duration.zero) {
          lastError = TimeoutException(
            'Generation budget exceeded for ${puzzleType.key}',
            puzzleGenerationTimeoutFor(
              engineId: puzzleType.key,
              difficulty: difficulty,
            ),
          );
          break;
        }
        if (kDebugMode) {
          debugPrint(
            '[Generation][Start] type=${puzzleType.key} '
            'difficulty=$difficulty size=${resolvedSize.id} '
            'seed=$attemptSeed attempt=$attempt '
            'attemptBudgetMs=${attemptTimeout.inMilliseconds}',
          );
        }
        try {
          // Move heavy generation to a background isolate to avoid UI jank/ANRs.
          final worker = ref.read(puzzleGenerationWorkerProvider);
          final generated = await worker.generate(
            PuzzleGenerationRequest(
              engineId: puzzleType.key,
              seedStr: attemptSeed,
              seed64: core.Seed.fromString(attemptSeed),
              size: resolvedSize,
              difficulty: difficultyScore,
            ),
            timeout: attemptTimeout,
          );
          if (token == _generationToken) {
            state = AsyncValue.data(generated);
          }
          if (kDebugMode) {
            debugPrint(
              '[Generation][Success] type=${puzzleType.key} '
              'difficulty=$difficulty size=${resolvedSize.id} '
              'seed=${generated.meta.seedStr} attempt=$attempt '
              'elapsedMs=${stopwatch.elapsedMilliseconds}',
            );
          }
          return generated;
        } catch (e, st) {
          lastError = e;
          lastStack = st;
          if (attempt == _maxGenerationAttempts) break;
          // brief microtask yield to keep UI responsive
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      // If we get here, all attempts failed.
      if (token == _generationToken) {
        state = AsyncValue.error(
          lastError ?? StateError('Generation failed'),
          lastStack ?? StackTrace.current,
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[Generation][Failure] type=${puzzleType.key} '
          'difficulty=$difficulty size=${resolvedSize.id} '
          'elapsedMs=${stopwatch.elapsedMilliseconds} '
          'error=${lastError ?? 'unknown'}',
        );
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
    state = const AsyncValue.data(null);
  }

  /// Whether the controller currently has an in-flight generation request.
  bool get isGenerating => state.isLoading;

  core.SizeOpt _getSizeFor(app.PuzzleType puzzleType, String difficulty) {
    switch (puzzleType) {
      case app.PuzzleType.takuzuBinary:
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
            return const core.SizeOpt(
              id: '12x12',
              description: '12x12',
              width: 12,
              height: 12,
            );
          default:
            return const core.SizeOpt(
              id: '8x8',
              description: '8x8',
              width: 8,
              height: 8,
            );
        }
      case app.PuzzleType.kakuroClassic:
        final core.KakuroAppProfileSurface surface = _activeKakuroAppSurface();
        final String sizeId = core.KakuroSupportedProfiles.appSizeForDifficulty(
          difficulty: difficulty,
          surface: surface,
        );
        return _parseSize(sizeId);
      case app.PuzzleType.killerQueens:
        return killerQueensAppSizeForDifficulty(difficulty);
      default:
        return _defaultSizeFor(puzzleType);
    }
  }

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
        return const core.SizeOpt(
          id: '9x9',
          description: '9x9',
          width: 9,
          height: 9,
        );
      case app.PuzzleType.nonogramMono:
        return const core.SizeOpt(
          id: '10x10',
          description: '10x10',
          width: 10,
          height: 10,
        );
      case app.PuzzleType.kakuroClassic:
        return _parseSize(
          core.KakuroSupportedProfiles.appProfilesForSurface(
            _activeKakuroAppSurface(),
          ).first.sizeId,
        );
      case app.PuzzleType.slitherlinkLoop:
        return const core.SizeOpt(
          id: '5x5',
          description: '5x5',
          width: 5,
          height: 5,
        );
      case app.PuzzleType.mathdokuClassic:
        // Updated default size to 9x9.
        return const core.SizeOpt(
          id: '9x9',
          description: '9x9',
          width: 9,
          height: 9,
        );
      case app.PuzzleType.killerQueens:
        return const core.SizeOpt(
          id: '8x8',
          description: '8x8',
          width: 8,
          height: 8,
        );
      case app.PuzzleType.takuzuBinary:
        return const core.SizeOpt(
          id: '8x8',
          description: '8x8',
          width: 8,
          height: 8,
        );
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

  Future<core.GeneratedPuzzle<dynamic>> _generateSlitherlinkOnDemand({
    required String difficulty,
    required core.SizeOpt size,
    required String seed,
  }) async {
    final service = ref.read(slitherlinkOnDemandProvider);
    return service.nextPuzzle(
      difficulty: difficulty,
      width: size.width,
      height: size.height,
      seed: seed,
    );
  }

  String _seedForAttempt(String baseSeed, int attempt) {
    if (attempt <= 1) {
      return baseSeed;
    }
    return '$baseSeed#attempt$attempt';
  }

  Duration _attemptTimeoutFor({
    required app.PuzzleType puzzleType,
    required Duration elapsed,
  }) {
    if (puzzleType == app.PuzzleType.kakuroClassic) {
      final Duration remaining =
          puzzleGenerationTimeoutFor(engineId: puzzleType.key) - elapsed;
      return remaining <= Duration.zero ? Duration.zero : remaining;
    }
    return puzzleGenerationTimeoutFor(engineId: puzzleType.key);
  }

  void _assertProfileAllowedForProduction({
    required app.PuzzleType puzzleType,
    required core.SizeOpt size,
    required String difficulty,
  }) {
    if (puzzleType != app.PuzzleType.kakuroClassic) {
      return;
    }
    final String normalizedDifficulty =
        core.KakuroSupportedProfiles.normalizeDifficulty(difficulty);
    final core.KakuroAppProfileSurface surface = _activeKakuroAppSurface();
    final bool allowed = core.KakuroSupportedProfiles.isAppProfileAllowed(
      sizeId: size.id,
      difficulty: normalizedDifficulty,
      surface: surface,
    );
    if (allowed) {
      return;
    }
    if (surface == core.KakuroAppProfileSurface.nonProduction) {
      throw StateError(
        'Kakuro profile ${size.id}/${normalizedDifficulty.toUpperCase()} '
        'is not enabled for non-production random play.',
      );
    }
    final core.KakuroProfileTier? tier = core.KakuroSupportedProfiles.tierFor(
      sizeId: size.id,
      difficulty: normalizedDifficulty,
    );
    final String reason = switch (tier) {
      core.KakuroProfileTier.benchmarkOnly =>
        'benchmark-only and not enabled for production random play',
      core.KakuroProfileTier.experimental =>
        'experimental and not enabled for production random play',
      _ => 'unsupported by production policy',
    };
    throw StateError(
      'Kakuro profile ${size.id}/${normalizedDifficulty.toUpperCase()} is $reason.',
    );
  }

  core.KakuroAppProfileSurface _activeKakuroAppSurface() {
    return AppEnvironment.isProduction
        ? core.KakuroAppProfileSurface.production
        : core.KakuroAppProfileSurface.nonProduction;
  }
}
