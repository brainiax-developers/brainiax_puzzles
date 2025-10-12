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

    // Register stub engines for testing
    registry.register(StubPuzzleEngine());
    registry.register(StubSudokuEngine());

    // Register real engines
    try {
      registry.register(SudokuEngine());
    } catch (e) {
      // Engine might not be available, continue
      if (kDebugMode) print('Warning: Could not register SudokuEngine: $e');
    }

    try {
      registry.register(NonogramEngine());
    } catch (e) {
      if (kDebugMode) print('Warning: Could not register NonogramEngine: $e');
    }

    try {
      registry.register(KakuroEngine());
    } catch (e) {
      if (kDebugMode) print('Warning: Could not register KakuroEngine: $e');
    }

    try {
      registry.register(SlitherlinkEngine());
    } catch (e) {
      if (kDebugMode) print('Warning: Could not register SlitherlinkEngine: $e');
    }

    try {
      registry.register(MathdokuEngine());
    } catch (e) {
      if (kDebugMode) print('Warning: Could not register MathdokuEngine: $e');
    }

    try {
      registry.register(FutoshikiEngine());
    } catch (e) {
      if (kDebugMode) print('Warning: Could not register FutoshikiEngine: $e');
    }

    try {
      registry.register(TakuzuEngine());
    } catch (e) {
      if (kDebugMode) print('Warning: Could not register TakuzuEngine: $e');
    }

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
