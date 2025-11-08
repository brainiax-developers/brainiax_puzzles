# Puzzle Core

A Dart package providing on-device deterministic puzzle generation with a stable API for pluggable puzzle engines.

## Features

- **On-device deterministic generation**: No network calls, no wall-clock timings in generation
- **64-bit integer arithmetic for RNG**: SplitMix64 seeding + xoroshiro128 core (placeholder implementation)
- **Complete metadata tracking**: Every `GeneratedPuzzle` includes engine version, RNG ID, size, difficulty, and seeds
- **Engine registry system**: Pluggable puzzle engines with stable API
- **Deterministic reproducibility**: Same parameters always produce identical puzzles
- **Daily and random seed formats**: Support for both daily puzzles and random play
 - **Difficulty-aware Takuzu generation**: Binary puzzle generator targets size + given density bands per difficulty (Easy 6x6 ~50–60%, Medium 8x8 ~40–50%, Hard 10x10 ~30–40%, Expert ≥12x12 ≤30%) while preserving uniqueness and enforcing all Takuzu rules.

## Key Design Principles

### Determinism
All puzzle generation is completely deterministic. Given the same:
- Engine version
- RNG ID  
- Size configuration
- Difficulty level
- Seed string and 64-bit seed

The exact same puzzle will be generated every time, regardless of when or where it's generated.

### On-Device Generation
- No network dependencies during puzzle generation
- No reliance on wall-clock time for puzzle content
- All randomness comes from seeded RNG
- Puzzles can be generated offline

### Stable API
The public API is designed to be "boring and stable" - it doesn't leak engine internals and provides a consistent interface for the app to interact with different puzzle types.

## Seed Formats

### Daily Seeds
Format: `"$puzzleId:${yyyyMMdd}"`

Example: `"sudoku:20240101"`

Daily seeds ensure that all users get the same puzzle on the same day for a given puzzle type.

### Random Play Seeds  
Format: `"$puzzleId:$userId:$sessionNonce"`

Example: `"sudoku:user123:session456"`

Random play seeds provide unique puzzles for individual users and sessions.

## Usage

### Basic Engine Registration

```dart
import 'package:puzzle_core/puzzle_core.dart';

// Register engines
final registry = EngineRegistry();
registry.register(StubPuzzleEngine());
registry.register(StubSudokuEngine());

// Get an engine
final engine = registry.getEngine('stub_sudoku') as StubSudokuEngine;
```

### Generating Puzzles

```dart
// Define puzzle parameters
final size = SizeOpt(
  id: '6x6',
  description: 'Takuzu Easy 6x6',
  width: 6,
  height: 6,
);

final difficulty = DifficultyScore(
  value: 0.0, // Pre-score hint (optional)
  level: 'easy',
);

// Generate puzzle
final puzzle = engine.generate(
  seedStr: 'sudoku:20240101',
  seed64: 12345,
  size: size,
  difficulty: difficulty,
);

// Access puzzle state and metadata
print('Takuzu size: ${puzzle.state.size}');
print('Engine Version: ${puzzle.meta.engineVersion}');
print('Seed: ${puzzle.meta.seedStr}');
```

### Validating Moves

```dart
// Create a move
final move = StubPuzzleMove(
  type: 'place_number',
  data: {'row': 5, 'col': 3, 'value': 7},
);

// Validate the move
final result = engine.validateMove(
  currentState: puzzle.state,
  move: move,
);

if (result.isValid) {
  print('Move is valid!');
  // Use result.newState for the updated puzzle state
} else {
  print('Invalid move: ${result.errorMessage}');
}
```

### Serialization

```dart
// Convert puzzle to JSON
final json = puzzle.toJson();

// Restore puzzle from JSON
final restoredPuzzle = GeneratedPuzzle.fromJson(
  json,
  (json) => StubPuzzleState.fromJson(json as Map<String, dynamic>),
);
```

## API Types

### Core Types
- `PuzzleEngine<S, M>`: Abstract base class for puzzle engines
- `EngineRegistry`: Manages engine registration and retrieval
- `GeneratedPuzzle<S>`: Contains puzzle state and metadata
- `PuzzleMetadata`: Complete generation metadata for reproducibility

### Supporting Types
- `MoveResult<S>`: Result of move validation
- `ValidationResult`: Result of puzzle state validation
- `DifficultyScore`: Difficulty level with value and description
- `SizeOpt`: Size configuration with dimensions
- `SeededRng`: Minimal RNG interface for deterministic generation

## Testing

The package includes comprehensive tests for:
- Registry functionality
- Serialization round-trips
- Deterministic generation
- Engine behavior

Run tests with:
```bash
dart test
```

## Stub Engines

The package includes stub engines for testing and validation:
- `StubPuzzleEngine`: Generic stub engine
- `StubSudokuEngine`: Sudoku-specific stub engine

These engines provide deterministic behavior for testing the registry and metadata systems without implementing real puzzle logic.

## Future Development

This package provides the foundation for puzzle engines. Future phases will include:
- Full RNG implementation (SplitMix64 + xoroshiro128)
- Real puzzle engines (Sudoku, Crossword, etc.)
- Advanced difficulty scoring
- Puzzle validation algorithms

## License

This package is part of the Brainiax Puzzles project.
