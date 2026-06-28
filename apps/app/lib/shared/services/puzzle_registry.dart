import 'package:flutter/material.dart';
import 'package:puzzle_core/puzzle_core.dart' as core;
import '../models/puzzle_type.dart' as app;
import '../models/puzzle_metadata.dart';
import '../models/puzzle_category.dart';
import '../config/app_environment.dart';

/// Registry for puzzle types with their metadata and UI properties.
class PuzzleRegistry {
  static final PuzzleRegistry _instance = PuzzleRegistry._internal();
  factory PuzzleRegistry() => _instance;
  PuzzleRegistry._internal();

  final Map<app.PuzzleType, PuzzleMetadata> _metadata = {};

  /// Initialize the puzzle registry with metadata for all available engines.
  void initialize() {
    final engineRegistry = core.EngineRegistry();

    // Clear existing metadata
    _metadata.clear();

    // Add metadata for each available puzzle type
    for (final puzzleType in app.PuzzleType.values) {
      final core.PuzzleEngine<dynamic, dynamic>? engine = engineRegistry
          .getEngineAs<core.PuzzleEngine<dynamic, dynamic>>(puzzleType.key);
      if (engine != null) {
        _metadata[puzzleType] = _createMetadataForType(puzzleType, engine);
      }
    }

    // If no engines are available, create stub engines for testing
    if (_metadata.isEmpty) {
      _createStubEnginesForTesting(engineRegistry);

      // Re-check for available engines after creating stubs
      for (final puzzleType in app.PuzzleType.values) {
        final core.PuzzleEngine<dynamic, dynamic>? engine = engineRegistry
            .getEngineAs<core.PuzzleEngine<dynamic, dynamic>>(puzzleType.key);
        if (engine != null) {
          _metadata[puzzleType] = _createMetadataForType(puzzleType, engine);
        }
      }
    }
  }

  /// Create stub engines for testing when no real engines are available.
  void _createStubEnginesForTesting(core.EngineRegistry engineRegistry) {
    // Create stub engines with the correct IDs for our puzzle types
    for (final puzzleType in app.PuzzleType.values) {
      if (!engineRegistry.hasEngine(puzzleType.key)) {
        try {
          engineRegistry.register(
            core.StubPuzzleEngine(
              engineId: puzzleType.key,
              engineName: puzzleType.displayName,
            ),
          );
        } catch (e) {
          // Engine might already exist, continue
        }
      }
    }
  }

  /// Get metadata for a specific puzzle type.
  PuzzleMetadata? getMetadata(app.PuzzleType type) {
    return _metadata[type];
  }

  /// Get all available puzzle types with metadata.
  List<PuzzleMetadata> getAllPuzzleMetadata() {
    return _metadata.values.toList();
  }

  /// Get all available puzzle types.
  List<app.PuzzleType> getAvailablePuzzleTypes() {
    return _metadata.keys.toList();
  }

  /// Check if a puzzle type is available.
  bool isPuzzleTypeAvailable(app.PuzzleType type) {
    return _metadata.containsKey(type);
  }

  /// Get the count of available puzzle types.
  int get availablePuzzleCount => _metadata.length;

  /// Get puzzles organized by category.
  Map<PuzzleCategory, List<PuzzleMetadata>> getPuzzlesByCategory() {
    final Map<PuzzleCategory, List<PuzzleMetadata>> categorized = {};

    for (final metadata in _metadata.values) {
      categorized.putIfAbsent(metadata.category, () => []).add(metadata);
    }

    // Ensure a stable, intentional ordering within each category so recently
    // enabled engines remain near the bottom without affecting availability.
    for (final entry in categorized.entries) {
      entry.value.sort(
        (a, b) => _sortKeyForType(a.type).compareTo(_sortKeyForType(b.type)),
      );
    }

    return categorized;
  }

  /// Get puzzles for a specific category.
  List<PuzzleMetadata> getPuzzlesForCategory(PuzzleCategory category) {
    return _metadata.values
        .where((metadata) => metadata.category == category)
        .toList();
  }

  /// Sort key to control display order of puzzles within a category.
  ///
  /// Normal playable puzzles come first, followed by Binary Takuzu, then
  /// Slitherlink and Killer Queens.
  int _sortKeyForType(app.PuzzleType type) {
    switch (type) {
      case app.PuzzleType.killerQueens:
        return 100;
      case app.PuzzleType.slitherlinkLoop:
        return 101;
      case app.PuzzleType.takuzuBinary:
        return 50;
      default:
        return 10;
    }
  }

  /// Create metadata for a specific puzzle type.
  PuzzleMetadata _createMetadataForType(
    app.PuzzleType type,
    core.PuzzleEngine<dynamic, dynamic> engine,
  ) {
    switch (type) {
      case app.PuzzleType.sudokuClassic:
        return PuzzleMetadata(
          type: type,
          displayName: type.displayName,
          description:
              'Fill the grid so every row, column, and box contains each number once.',
          icon: Icons.grid_on,
          accentColors: const [Color(0xFF2196F3), Color(0xFF1976D2)],
          supportedSizes: ['9x9', '6x6', '4x4'],
          supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
          supportsHints: engine.capabilities.supportsHints,
          category: PuzzleCategory.logic,
        );

      case app.PuzzleType.kakuro:
        return PuzzleMetadata(
          type: type,
          displayName: type.displayName,
          description:
              'Fill the white cells with digits 1-9 so they sum to the clue. No digit can repeat in a run.',
          icon: Icons.looks_3, // Or something more fitting
          accentColors: const [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
          supportedSizes: ['7x7', '9x9'],
          supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
          supportsHints: engine.capabilities.supportsHints,
          category: PuzzleCategory.logic,
        );

      case app.PuzzleType.nonogramMono:
        return PuzzleMetadata(
          type: type,
          displayName: type.displayName,
          description:
              'Reveal the picture by filling cells to match the row and column clues.',
          icon: Icons.crop_square,
          accentColors: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
          // Prefer engine-supported defaults first; 5x5 is not supported by current engine
          supportedSizes: ['10x10', '15x15', '20x20', '5x5'],
          supportedDifficulties: ['Easy', 'Medium', 'Hard'],
          supportsHints: engine.capabilities.supportsHints,
          category: PuzzleCategory.logic,
        );


      case app.PuzzleType.slitherlinkLoop:
        return PuzzleMetadata(
          type: type,
          displayName: type.displayName,
          description:
              'Draw a single loop around the grid that satisfies every clue.',
          icon: Icons.circle_outlined,
          accentColors: const [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
          supportedSizes: ['5x5', '7x7', '10x10'],
          supportedDifficulties: ['Easy', 'Medium', 'Hard'],
          supportsHints: engine.capabilities.supportsHints,
          category: PuzzleCategory.logic,
        );

      case app.PuzzleType.mathdokuClassic:
        return PuzzleMetadata(
          type: type,
          displayName: type.displayName,
          description:
              'Complete the Latin square while making every cage math target work.',
          icon: Icons.calculate,
          accentColors: const [Color(0xFFE91E63), Color(0xFFC2185B)],
          // Updated sizes: add 9x9, remove unsupported 8x8, order largest first for default selection.
          supportedSizes: ['9x9', '6x6', '4x4'],
          supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
          supportsHints: engine.capabilities.supportsHints,
          category: PuzzleCategory.logic,
        );

      case app.PuzzleType.killerQueens:
        return PuzzleMetadata(
          type: type,
          displayName: type.displayName,
          description:
              'Place queens so rows, columns, cages, and diagonals all stay valid.',
          icon: Icons.catching_pokemon,
          accentColors: const [Color(0xFF26C6DA), Color(0xFF00838F)],
          supportedSizes: ['6x6', '8x8', '10x10', '12x12'],
          supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
          supportsHints: engine.capabilities.supportsHints,
          category: PuzzleCategory.logic,
        );

      case app.PuzzleType.takuzuBinary:
        return PuzzleMetadata(
          type: type,
          displayName: type.displayName,
          description:
              'Balance zeros and ones so every row and column stays unique.',
          icon: Icons.code,
          accentColors: const [Color(0xFF607D8B), Color(0xFF455A64)],
          supportedSizes: ['6x6', '8x8', '10x10', '12x12'],
          supportedDifficulties: ['Easy', 'Medium', 'Hard', 'Expert'],
          supportsHints: engine.capabilities.supportsHints,
          category: PuzzleCategory.logic,
        );
    }
  }
}
