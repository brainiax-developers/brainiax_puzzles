/// Stub engines for testing and validation.
/// 
/// These engines provide minimal implementations that return
/// deterministic structures based on seeds. They don't perform
/// real puzzle generation or solving - they're just for validating
/// the registry and metadata systems.
library puzzle_core.stub_engine;

import '../api_types.dart';
import '../util/determinism.dart';
import '../util/seeded_rng.dart';
import '../util/soft_timeout.dart';

/// A simple stub state for testing.
class StubPuzzleState {
  final String id;
  final Map<String, dynamic> data;
  
  const StubPuzzleState({
    required this.id,
    required this.data,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'data': data,
  };
  
  factory StubPuzzleState.fromJson(Map<String, dynamic> json) => StubPuzzleState(
    id: json['id'] as String? ?? '',
    data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
  );
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StubPuzzleState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          data == other.data;
  
  @override
  int get hashCode => Object.hash(id, data);
  
  @override
  String toString() => 'StubPuzzleState(id: $id, data: $data)';
}

/// A simple stub move for testing.
class StubPuzzleMove {
  final String type;
  final Map<String, dynamic> data;
  
  const StubPuzzleMove({
    required this.type,
    required this.data,
  });
  
  Map<String, dynamic> toJson() => {
    'type': type,
    'data': data,
  };
  
  factory StubPuzzleMove.fromJson(Map<String, dynamic> json) => StubPuzzleMove(
    type: json['type'] as String? ?? '',
    data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
  );
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StubPuzzleMove &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          data == other.data;
  
  @override
  int get hashCode => Object.hash(type, data);
  
  @override
  String toString() => 'StubPuzzleMove(type: $type, data: $data)';
}

/// Stub puzzle engine for testing.
/// 
/// This engine generates deterministic stub puzzles based on
/// the provided seed and parameters. It's designed to validate
/// the registry and metadata systems without implementing
/// real puzzle logic.
class StubPuzzleEngine extends PuzzleEngine<StubPuzzleState, StubPuzzleMove> {
  @override
  String get id => 'stub';
  
  @override
  String get name => 'Stub Puzzle Engine';
  
  @override
  String get version => '1.0.0';
  
  @override
  GeneratedPuzzle<StubPuzzleState> generate({
    required String seedStr,
    required int seed64,
    required SizeOpt size,
    required DifficultyScore difficulty,
  }) {
    // Create a deterministic RNG from the seed
    final rng = SeededRng(seed64);
    final SoftTimeout budget = SoftTimeout(maxIterations: 256);
    
    // Generate deterministic data based on seed and parameters
    final puzzleData = <String, dynamic>{
      'generated_at': seed64, // Use seed for deterministic timestamp
      'size_width': size.width,
      'size_height': size.height,
      'difficulty_level': difficulty.level,
      'random_values': <int>[],
    };

    // Generate some deterministic "random" values
    for (int i = 0; i < 10; i++) {
      budget.tick();
      puzzleData['random_values'].add(rng.nextIntInRange(100));
    }
    
    // Create a deterministic puzzle ID based on seed
    final puzzleId = 'puzzle_${seed64.abs()}_${size.id}_${difficulty.level}';
    
    final state = StubPuzzleState(
      id: puzzleId,
      data: puzzleData,
    );

    DeterminismGuard.assertNoFloatsOrDateTimes(state.data);
    
    final meta = PuzzleMetadata(
      engineVersion: version,
      rngId: SeededRng.rngId,
      size: size,
      difficulty: difficulty,
      seedStr: seedStr,
      seed64: seed64,
    );
    
    return GeneratedPuzzle(
      state: state,
      meta: meta,
    );
  }
  
  @override
  MoveResult<StubPuzzleState> validateMove({
    required StubPuzzleState currentState,
    required StubPuzzleMove move,
  }) {
    // Simple validation logic for testing
    if (move.type == 'invalid') {
      return MoveResult.failure('Invalid move type');
    }
    
    // Create a new state with the move applied
    final newData = Map<String, dynamic>.from(currentState.data);
    newData['last_move'] = move.toJson();
    newData['move_count'] = (newData['move_count'] ?? 0) + 1;
    
    final newState = StubPuzzleState(
      id: currentState.id,
      data: newData,
    );
    
    return MoveResult.success(newState);
  }
  
  @override
  bool isSolved(StubPuzzleState state) {
    // Simple solved condition for testing
    final moveCount = state.data['move_count'] ?? 0;
    return moveCount >= 5; // Consider solved after 5 moves
  }
}

/// Sudoku stub engine for testing.
/// 
/// This engine simulates a Sudoku puzzle generator without
/// implementing real Sudoku logic.
class StubSudokuEngine extends PuzzleEngine<StubPuzzleState, StubPuzzleMove> {
  @override
  String get id => 'stub_sudoku';
  
  @override
  String get name => 'Stub Sudoku Engine';
  
  @override
  String get version => '1.0.0';
  
  @override
  GeneratedPuzzle<StubPuzzleState> generate({
    required String seedStr,
    required int seed64,
    required SizeOpt size,
    required DifficultyScore difficulty,
  }) {
    final rng = SeededRng(seed64);
    final SoftTimeout budget = SoftTimeout(maxIterations: 9 * 9 * 2);
    
    // Generate a 9x9 grid with some deterministic values
    final grid = <List<int>>[];
    for (int row = 0; row < 9; row++) {
      final rowData = <int>[];
      for (int col = 0; col < 9; col++) {
        // Fill some cells deterministically based on seed
        budget.tick();
        if ((row + col + seed64) % 3 == 0) {
          rowData.add((rng.nextIntInRange(9) + 1));
        } else {
          rowData.add(0); // Empty cell
        }
      }
      grid.add(rowData);
    }
    
    final puzzleData = <String, dynamic>{
      'type': 'sudoku',
      'grid': grid,
      'size': '9x9',
      'difficulty': difficulty.level,
      'seed': seed64,
    };
    
    final puzzleId = 'sudoku_${seed64.abs()}_${difficulty.level}';
    
    final state = StubPuzzleState(
      id: puzzleId,
      data: puzzleData,
    );

    DeterminismGuard.assertNoFloatsOrDateTimes(state.data);
    
    final meta = PuzzleMetadata(
      engineVersion: version,
      rngId: SeededRng.rngId,
      size: size,
      difficulty: difficulty,
      seedStr: seedStr,
      seed64: seed64,
    );
    
    return GeneratedPuzzle(
      state: state,
      meta: meta,
    );
  }
  
  @override
  MoveResult<StubPuzzleState> validateMove({
    required StubPuzzleState currentState,
    required StubPuzzleMove move,
  }) {
    // Simple Sudoku move validation
    if (move.type != 'place_number') {
      return MoveResult.failure('Invalid move type for Sudoku');
    }
    
    final row = move.data['row'] as int?;
    final col = move.data['col'] as int?;
    final value = move.data['value'] as int?;
    
    if (row == null || col == null || value == null) {
      return MoveResult.failure('Missing required move data');
    }
    
    if (row < 0 || row >= 9 || col < 0 || col >= 9) {
      return MoveResult.failure('Invalid cell position');
    }
    
    if (value < 1 || value > 9) {
      return MoveResult.failure('Invalid number value');
    }
    
    // Create new state with the move applied
    final newData = Map<String, dynamic>.from(currentState.data);
    final grid = List<List<int>>.from(
      (newData['grid'] as List).map((row) => List<int>.from(row))
    );
    
    grid[row][col] = value;
    newData['grid'] = grid;
    newData['last_move'] = move.toJson();
    
    final newState = StubPuzzleState(
      id: currentState.id,
      data: newData,
    );
    
    return MoveResult.success(newState);
  }
  
  @override
  bool isSolved(StubPuzzleState state) {
    final grid = state.data['grid'] as List<List<int>>?;
    if (grid == null) return false;
    
    // Simple solved check - all cells filled
    for (final row in grid) {
      for (final cell in row) {
        if (cell == 0) return false;
      }
    }
    return true;
  }
}

/// Utility function to register all stub engines.
/// 
/// This function registers the stub engines with the global registry
/// for testing and development purposes.
void registerStubEngines() {
  final registry = EngineRegistry();
  registry.register(StubPuzzleEngine());
  registry.register(StubSudokuEngine());
}
