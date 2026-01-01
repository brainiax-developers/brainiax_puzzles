import 'package:flutter/foundation.dart';
import 'package:puzzle_core/puzzle_core.dart';

/// Service for registering all available puzzle engines.
class EngineRegistryService {
  static final EngineRegistryService _instance = EngineRegistryService._internal();
  factory EngineRegistryService() => _instance;
  EngineRegistryService._internal();

  bool _isInitialized = false;

  /// Initialize and register all available puzzle engines.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final registry = EngineRegistry();

    // Helper to register a real engine and fall back to registering a stub
    // with the same engineId if the real engine couldn't be registered.
    Future<void> _registerWithPerEngineFallback({
      required PuzzleEngine Function() realEngineFactory,
      required String fallbackEngineId,
      required String fallbackEngineName,
    }) async {
      try {
        final engine = realEngineFactory();
        if (!registry.hasEngine(engine.id)) {
          registry.register(engine);
          if (kDebugMode) print('Registered engine ${engine.id}');
        }
      } catch (e) {
        // If registering the real engine failed, register a stub with the
        // same engine ID so the rest of the app that expects that ID works.
        try {
          if (!registry.hasEngine(fallbackEngineId)) {
            registry.register(StubPuzzleEngine(engineId: fallbackEngineId, engineName: fallbackEngineName));
            if (kDebugMode) print('Registered stub engine for $fallbackEngineId due to error: $e');
          }
        } catch (e2) {
          if (kDebugMode) print('Warning: Could not register fallback stub for $fallbackEngineId: $e2');
        }
      }
    }

    // Register engines per-type with per-engine fallback to avoid leaving
    // specific puzzle types without an engine.
    await _registerWithPerEngineFallback(
      realEngineFactory: () => SudokuEngine(),
      fallbackEngineId: 'sudoku_classic',
      fallbackEngineName: 'Classic Sudoku',
    );

    await _registerWithPerEngineFallback(
      realEngineFactory: () => NonogramEngine(),
      fallbackEngineId: 'nonogram_mono',
      fallbackEngineName: 'Monochrome Nonogram',
    );

    await _registerWithPerEngineFallback(
      realEngineFactory: () => KakuroEngine(),
      fallbackEngineId: 'kakuro_classic',
      fallbackEngineName: 'Classic Kakuro',
    );

    await _registerWithPerEngineFallback(
      realEngineFactory: () => SlitherlinkEngine(),
      fallbackEngineId: 'slitherlink_loop',
      fallbackEngineName: 'Slitherlink Loop',
    );

    await _registerWithPerEngineFallback(
      realEngineFactory: () => MathdokuEngine(),
      fallbackEngineId: 'mathdoku_classic',
      fallbackEngineName: 'Classic Mathdoku',
    );

    await _registerWithPerEngineFallback(
      realEngineFactory: () => KillerQueensEngine(),
      fallbackEngineId: 'killer_queens',
      fallbackEngineName: 'Killer Queens',
    );

    await _registerWithPerEngineFallback(
      realEngineFactory: () => TakuzuEngine(),
      fallbackEngineId: 'takuzu_binary',
      fallbackEngineName: 'Binary Takuzu',
    );

    _isInitialized = true;
    if (kDebugMode) print('Engine registry initialized with ${registry.engineCount} engines');
  }

  /// Get the list of available engine IDs.
  List<String> getAvailableEngines() {
    return EngineRegistry().registeredIds;
  }

  /// Check if a specific engine is available.
  bool isEngineAvailable(String engineId) {
    return EngineRegistry().hasEngine(engineId);
  }
}
