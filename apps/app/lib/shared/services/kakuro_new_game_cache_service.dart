import 'dart:async';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle_type.dart';
import 'engine_registry_service.dart';
import 'generation_isolate.dart';
import 'puzzle_registry.dart';
import 'seed_service.dart';

/// Buffered cache for Kakuro random play puzzles with warm-up and perpetual top-off.
///
/// Key properties:
/// - Difficulties: easy, medium, hard, expert
/// - Targets: {easy:2, medium:2, hard:2, expert:3}; max buffer = min+1 (expert up to 4)
/// - Warm-up: fills to targets round-robin at app startup (non-blocking)
/// - Top-off: after serving a puzzle, enqueue a refill for that difficulty
/// - Persistence: small on-disk cache per difficulty using SharedPreferences
/// - Resilience: retries with exponential backoff + jitter, never surfaces errors to UI
/// - Concurrency: per-difficulty locks prevent duplicate refills
/// - Lifecycle: pause on background, resume on foreground
class KakuroNewGameCacheService {
  KakuroNewGameCacheService(this._prefs);

  final SharedPreferences _prefs;

  // Difficulty keys are lowercase consistent with UI labels
  static const List<String> difficulties = ['easy', 'medium', 'hard', 'expert'];
  static const Map<String, int> _minTargets = {
    'easy': 2,
    'medium': 2,
    'hard': 2,
    'expert': 3,
  };

  static int _maxFor(String difficulty) => _minTargets[difficulty]! + 1; // expert up to 4

  final Map<String, List<core.GeneratedPuzzle<dynamic>>> _buffers = {
    'easy': <core.GeneratedPuzzle<dynamic>>[],
    'medium': <core.GeneratedPuzzle<dynamic>>[],
    'hard': <core.GeneratedPuzzle<dynamic>>[],
    'expert': <core.GeneratedPuzzle<dynamic>>[],
  };

  final Map<String, _AsyncMutex> _locks = {
    'easy': _AsyncMutex(),
    'medium': _AsyncMutex(),
    'hard': _AsyncMutex(),
    'expert': _AsyncMutex(),
  };

  bool _initialized = false;
  bool _paused = false;
  bool _warming = false;
  Timer? _topOffTicker;

  // Telemetry (simple counters; wire to analytics later)
  int cacheHits = 0;
  int cacheMisses = 0;

  // Storage keys (separate from Daily system)
  static String _storeKey(String difficulty) => 'kakuro_cache_random_$difficulty';

  Future<void> initialize() async {
    if (_initialized) return;

    // Ensure engines/registry exist; fail soft if not
    try { await EngineRegistryService().initialize(); } catch (_) {}

    await _restoreFromDisk();

    // Start periodic top-off sweeps (lightweight) to catch any gaps from crashes
    _topOffTicker?.cancel();
    _topOffTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_paused) return;
      unawaited(_topOffAll());
    });

    _initialized = true;
  }

  /// Whether there is at least one cached puzzle for the difficulty.
  bool hasCached(String difficulty) {
    final d = difficulty.toLowerCase();
    return _buffers[d]?.isNotEmpty == true;
  }

  /// Current buffer count for the difficulty (for diagnostics/UX decisions).
  int bufferCount(String difficulty) {
    final d = difficulty.toLowerCase();
    return _buffers[d]?.length ?? 0;
  }

  /// Start warm-up to reach minimum targets via round-robin. Non-blocking.
  Future<void> warmUpRoundRobin() async {
    if (!_initialized || _warming) return;
    _warming = true;
    try {
      // Round-robin difficulties until all reach min targets or paused
      while (!_paused) {
        bool anyBelow = false;
        for (final d in difficulties) {
          if (_buffers[d]!.length < _minTargets[d]!) {
            anyBelow = true;
            await _ensureOne(d, urgent: false);
            // Small yield to keep UI smooth
            await Future.delayed(const Duration(milliseconds: 30));
          }
        }
        if (!anyBelow) break;
      }
    } finally {
      _warming = false;
    }
  }

  /// Serve a puzzle from cache if available; otherwise generate urgently with retry.
  /// Always schedules a background top-off for the given difficulty.
  Future<core.GeneratedPuzzle<dynamic>> takeOrGenerateUrgent({
    required String difficulty,
  }) async {
    assert(difficulties.contains(difficulty.toLowerCase()));
    final d = difficulty.toLowerCase();

    // Fast path: pop from buffer
    final existing = _pop(d);
    if (existing != null) {
      cacheHits++;
      // Fire-and-forget refill
      unawaited(_topOff(d));
      return existing;
    }

    // Miss: immediately start urgent generation (with retries)
    cacheMisses++;
    final generated = await _generateWithRetry(d, isolated: true);
    // After urgent generate, still schedule a background top-off to reach target
    unawaited(_topOff(d));
    return generated;
  }

  /// External lifecycle hooks
  void pause() {
    _paused = true;
  }

  void resume() {
    final wasPaused = _paused;
    _paused = false;
    if (wasPaused) {
      // Kick a quick top-off after resume to replenish
      unawaited(_topOffAll());
    }
  }

  /// Dispose timers; does not clear buffers.
  void dispose() {
    _topOffTicker?.cancel();
    _topOffTicker = null;
  }

  // --- Internal helpers ---

  core.GeneratedPuzzle<dynamic>? _pop(String difficulty) {
    final buf = _buffers[difficulty]!;
    if (buf.isNotEmpty) {
      final item = buf.removeAt(0);
      unawaited(_persistBuffer(difficulty));
      return item;
    }
    return null;
  }

  Future<void> _topOff(String difficulty) async {
    if (_paused) return;
    final minTarget = _minTargets[difficulty]!;
    final maxTarget = _maxFor(difficulty);
    await _locks[difficulty]!.protect(() async {
      // Re-check inside lock
      final len = _buffers[difficulty]!.length;
      if (len >= minTarget) return;
      // Generate until min target, but do not exceed maxTarget
      while (!_paused && _buffers[difficulty]!.length < minTarget) {
        if (_buffers[difficulty]!.length >= maxTarget) break;
        try {
          final g = await _generateWithRetry(difficulty, isolated: true);
          _buffers[difficulty]!.add(g);
          await _persistBuffer(difficulty);
        } catch (e) {
          // Swallow and retry on next tick; backoff is inside _generateWithRetry
          if (kDebugMode) {
            // ignore: avoid_print
            print('KakuroCache top-off failed for $difficulty: $e');
          }
          break; // leave loop; retry will be scheduled via periodic sweep
        }
      }
    });
  }

  Future<void> _topOffAll() async {
    for (final d in difficulties) {
      // Schedule sequentially with tiny yields to avoid saturating CPU
      await _topOff(d);
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> _ensureOne(String difficulty, {required bool urgent}) async {
    if (_buffers[difficulty]!.length >= _minTargets[difficulty]!) return;
    await _locks[difficulty]!.protect(() async {
      if (_buffers[difficulty]!.length >= _minTargets[difficulty]!) return;
      try {
        final g = await _generateWithRetry(difficulty, isolated: true);
        if (_buffers[difficulty]!.length < _maxFor(difficulty)) {
          _buffers[difficulty]!.add(g);
          await _persistBuffer(difficulty);
        }
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('KakuroCache ensureOne failed for $difficulty: $e');
        }
      }
    });
  }

  Future<core.GeneratedPuzzle<dynamic>> _generateWithRetry(String difficulty, {required bool isolated}) async {
    // Guard engine availability
    final registry = PuzzleRegistry();
    registry.initialize();
    final kakuroMeta = registry.getMetadata(PuzzleType.kakuroClassic);
    final engineAvailable = core.EngineRegistry().hasEngine(PuzzleType.kakuroClassic.key);
    if (!engineAvailable || kakuroMeta == null) {
      throw StateError('Kakuro engine not available');
    }

    final sizeStr = kakuroMeta.supportedSizes.isNotEmpty ? kakuroMeta.supportedSizes.first : '9x9';
    final size = _parseSize(sizeStr);
    final diffScore = _parseDifficulty(difficulty);

    // Exponential backoff with jitter
    const int maxBackoffMs = 5000;
    int delayMs = 250;
    Object? lastError;
    for (int attempt = 1; attempt <= 9999; attempt++) {
      final seed = SeedService().generateRandomSeed(PuzzleType.kakuroClassic.key);
      try {
        final Duration attemptTimeout = const Duration(seconds: 4);
        final generated = await generatePuzzleIsolated(
          engineId: PuzzleType.kakuroClassic.key,
          seedStr: seed,
          seed64: seed.hashCode,
          size: size,
          difficulty: diffScore,
        ).timeout(attemptTimeout);
        return generated;
      } catch (e) {
        lastError = e;
        // Backoff with jitter [delayMs/2, delayMs]
        final jitter = Random().nextDouble() * (delayMs / 2);
        final sleepMs = (delayMs / 2 + jitter).toInt();
        await Future.delayed(Duration(milliseconds: sleepMs));
        delayMs = min(delayMs * 2, maxBackoffMs);
      }
    }
    throw lastError ?? StateError('Unexpected generation failure');
  }

  Future<void> _restoreFromDisk() async {
    for (final d in difficulties) {
      try {
        final rawList = _prefs.getStringList(_storeKey(d)) ?? const <String>[];
        final List<core.GeneratedPuzzle<dynamic>> restored = <core.GeneratedPuzzle<dynamic>>[];
        for (final raw in rawList) {
          final map = json.decode(raw) as Map<String, dynamic>;
          final gp = core.GeneratedPuzzle<core.KakuroBoard>.fromJson(
            map,
            (m) => core.KakuroBoard.fromJson(m),
          );
          // Basic validation: ensure engine id matches kakuro and difficulty is expected bucket
          if (gp.meta.difficulty.level.toLowerCase() == d) {
            restored.add(gp);
          }
        }
        // Cap to max buffer size
        final cap = _maxFor(d);
        _buffers[d] = restored.take(cap).toList();
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('KakuroCache restore failed for $d: $e');
        }
        _buffers[d] = <core.GeneratedPuzzle<dynamic>>[];
      }
    }
  }

  Future<void> _persistBuffer(String difficulty) async {
    try {
    final list = _buffers[difficulty]!
          .take(_maxFor(difficulty))
      .map((gp) => json.encode(gp.toJson()))
          .toList(growable: false);
      await _prefs.setStringList(_storeKey(difficulty), list);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('KakuroCache persist failed for $difficulty: $e');
      }
    }
  }

  // Helpers matching controller defaults
  core.SizeOpt _parseSize(String size) {
    final parts = size.split('x');
    final w = int.parse(parts[0]);
    final h = int.parse(parts[1]);
    return core.SizeOpt(id: size, description: size, width: w, height: h);
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

/// Simple async mutex for guarding per-difficulty refills.
class _AsyncMutex {
  Future<void> _last = Future<void>.value();

  Future<T> protect<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final prev = _last;
    _last = completer.future;
    return prev.then((_) => action()).whenComplete(() {
      if (!completer.isCompleted) completer.complete();
    });
  }
}

/// Riverpod provider for the Kakuro cache service.
final kakuroCacheProvider = Provider<KakuroNewGameCacheService>((ref) {
  // SharedPreferences is async; use a future provider bootstrapping pattern
  throw UnimplementedError('Use kakuroCacheInitProvider to obtain service');
});

/// Initializes the Kakuro cache service with SharedPreferences and exposes it.
final kakuroCacheInitProvider = FutureProvider<KakuroNewGameCacheService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final service = KakuroNewGameCacheService(prefs);
  await service.initialize();
  // Kick off warm-up non-blocking; round-robin until min targets
  unawaited(service.warmUpRoundRobin());
  return service;
});
