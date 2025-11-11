import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'generation_isolate.dart';

import '../models/models.dart';
import 'puzzle_registry.dart';
import 'seed_service.dart';
import 'engine_registry_service.dart';

/// Simple in-memory cache holding one generated puzzle per (type,difficulty).
/// Runs a best-effort preload of one puzzle for each supported difficulty for
/// every registered puzzle type.
class PuzzlePreloadService {
  PuzzlePreloadService();

  final Map<String, core.GeneratedPuzzle<dynamic>> _cache = {};
  bool _isPreloading = false;

  static String _cacheKey(PuzzleType type, String difficulty) => '${type.key}::$difficulty'.toLowerCase();

  /// Start a background preload. Returns immediately if already running.
  Future<void> preloadAll({Duration interItemYield = const Duration(milliseconds: 50)}) async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      // Ensure the engine registry has been initialized (idempotent)
      try {
        await EngineRegistryService().initialize();
      } catch (e) {
        // Initialization may fail in constrained environments; log in debug
        // and continue — PuzzleRegistry.initialize will attempt to provide
        // stub engines if necessary.
        // ignore: avoid_print
        if (kDebugMode) print('Warning: EngineRegistryService.initialize() failed: $e');
      }

      final registry = PuzzleRegistry();
      // Ensure registry is initialized (idempotent)
      registry.initialize();

      final allMetadata = registry.getAllPuzzleMetadata();
      for (final metadata in allMetadata) {
        for (final difficulty in metadata.supportedDifficulties) {
          final key = _cacheKey(metadata.type, difficulty);
          // Skip if we already have a cached puzzle
          if (_cache.containsKey(key)) continue;

          try {
            final engine = core.EngineRegistry().getEngineAs<core.PuzzleEngine<dynamic, dynamic>>(metadata.type.key);
            if (engine == null) {
              if (kDebugMode) print('No engine available for ${metadata.type.key} — skipping preload');
              continue;
            }

            final seed = SeedService().generateRandomSeed(metadata.type.key);
            final sizeOpt = _getSizeFor(metadata.type, difficulty, metadata);
            final diffScore = _parseDifficulty(difficulty);

            // Generate on a background isolate to avoid jank.
            final Duration attemptTimeout =
                metadata.type == PuzzleType.kakuroClassic ? const Duration(seconds: 3) : const Duration(seconds: 2);
            final generated = await generatePuzzleIsolated(
              engineId: metadata.type.key,
              seedStr: seed,
              seed64: seed.hashCode,
              size: sizeOpt,
              difficulty: diffScore,
            ).timeout(attemptTimeout);
            _cache[key] = generated;
            if (kDebugMode) print('Preloaded puzzle for ${metadata.type.key} @ $difficulty (seed: $seed)');
          } catch (e) {
            if (kDebugMode) print('Preload failed for ${metadata.type.key} @ $difficulty: $e');
          }

          // Yield to event loop so we don't permanently block startup.
          await Future.delayed(interItemYield);
        }
      }
    } finally {
      _isPreloading = false;
    }
  }

  core.GeneratedPuzzle<dynamic>? getCached(PuzzleType puzzleType, String difficulty) {
    final key = _cacheKey(puzzleType, difficulty);
    return _cache[key];
  }

  bool get hasPreloaded => _cache.isNotEmpty;

  // --- Helpers copied from controller logic (kept local to avoid coupling) ---
  core.SizeOpt _getSizeFor(PuzzleType puzzleType, String difficulty, PuzzleMetadata metadata) {
    switch (puzzleType) {
      case PuzzleType.takuzuBinary:
        switch (difficulty.toLowerCase()) {
          case 'easy':
            return const core.SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6);
          case 'medium':
            return const core.SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8);
          case 'hard':
            return const core.SizeOpt(id: '10x10', description: '10x10', width: 10, height: 10);
          case 'expert':
            return const core.SizeOpt(id: '12x12', description: '12x12', width: 12, height: 12);
          default:
            return const core.SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8);
        }
      default:
        final sizeStr = metadata.supportedSizes.isNotEmpty ? metadata.supportedSizes.first : null;
        return sizeStr != null ? _parseSize(sizeStr) : _defaultSizeFor(puzzleType);
    }
  }

  core.SizeOpt _defaultSizeFor(PuzzleType puzzleType) {
    switch (puzzleType) {
      case PuzzleType.sudokuClassic:
        return const core.SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
      case PuzzleType.nonogramMono:
        return const core.SizeOpt(id: '10x10', description: '10x10', width: 10, height: 10);
      case PuzzleType.kakuroClassic:
        return const core.SizeOpt(id: '9x9', description: '9x9', width: 9, height: 9);
      case PuzzleType.slitherlinkLoop:
        return const core.SizeOpt(id: '7x7', description: '7x7', width: 7, height: 7);
      case PuzzleType.mathdokuClassic:
        return const core.SizeOpt(id: '6x6', description: '6x6', width: 6, height: 6);
      case PuzzleType.killerQueens:
        return const core.SizeOpt(id: '8x8', description: '8x8', width: 8, height: 8);
      case PuzzleType.takuzuBinary:
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

/// Riverpod provider exposing a singleton preload service.
final puzzlePreloadProvider = Provider<PuzzlePreloadService>((ref) {
  return PuzzlePreloadService();
});
