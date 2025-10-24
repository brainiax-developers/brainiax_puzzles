import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_core/puzzle_core.dart';
import 'engine_provider.dart';

/// Provider for current game state.
final gameStateProvider = NotifierProvider<GameStateNotifier, GameState?>(() {
  return GameStateNotifier();
});

/// Game state notifier that handles puzzle state, moves, and undo/redo.
class GameStateNotifier extends Notifier<GameState?> {
  final List<GameMove> _moveHistory = [];
  int _currentMoveIndex = -1;
  GeneratedPuzzle? _initialPuzzle;

  @override
  GameState? build() => null;

  /// Start a new game with the specified engine and parameters.
  Future<void> startNewGame({
    required String engineId,
    required String seed,
    required String difficulty,
    required String size,
  }) async {
    final engine = ref.read(engineProvider(engineId));
    if (engine == null) {
      throw Exception('Engine not found: $engineId');
    }

    // Parse parameters
    final difficultyScore = _parseDifficulty(difficulty);
    final sizeOpt = _parseSize(size);
    final seed64 = seed.hashCode;

    // Generate puzzle
    final puzzle = engine.generate(
      seedStr: seed,
      seed64: seed64,
      size: sizeOpt,
      difficulty: difficultyScore,
    );

    // Create game state
    final gameState = GameState(
      engineId: engineId,
      seed: seed,
      difficulty: difficulty,
      size: size,
      puzzle: puzzle,
      isSolved: false,
      startTime: DateTime.now(),
    );

    // Reset move history
    _moveHistory.clear();
    _currentMoveIndex = -1;
    _initialPuzzle = puzzle;

    state = gameState;
  }

  /// Initialize the game state from an existing generated puzzle instance.
  ///
  /// This avoids re-generating the puzzle on-device and preserves the provided
  /// puzzle as the initial puzzle for undo/redo reconstruction.
  Future<void> startWithGeneratedPuzzle({
    required String engineId,
    required String seed,
    required String difficulty,
    required String size,
    required GeneratedPuzzle puzzle,
  }) async {
    // Reset move history
    _moveHistory.clear();
    _currentMoveIndex = -1;
    _initialPuzzle = puzzle;

    final gameState = GameState(
      engineId: engineId,
      seed: seed,
      difficulty: difficulty,
      size: size,
      puzzle: puzzle,
      isSolved: false,
      startTime: DateTime.now(),
    );

    state = gameState;
  }

  /// Make a move in the current game.
  Future<void> makeMove(dynamic move) async {
    if (state == null) return;

    final engine = ref.read(engineProvider(state!.engineId));
    if (engine == null) return;

    // Validate move
    final result = engine.validateMove(
      currentState: state!.puzzle.state,
      move: move,
    );

    if (!result.isValid) {
      throw Exception('Invalid move: ${result.errorMessage}');
    }

    // Create move record
    final gameMove = GameMove(
      move: move,
      timestamp: DateTime.now(),
      moveIndex: _currentMoveIndex + 1,
    );

    // Add to history (remove any moves after current index)
    if (_currentMoveIndex < _moveHistory.length - 1) {
      _moveHistory.removeRange(_currentMoveIndex + 1, _moveHistory.length);
    }
    _moveHistory.add(gameMove);
    _currentMoveIndex = _moveHistory.length - 1;

    // Update state
    final newPuzzle = GeneratedPuzzle(
      state: result.newState!,
      meta: state!.puzzle.meta,
      telemetry: state!.puzzle.telemetry,
    );

    final isSolved = engine.isSolved(result.newState!);

    state = state!.copyWith(
      puzzle: newPuzzle,
      isSolved: isSolved,
      lastMoveTime: DateTime.now(),
    );
  }

  /// Undo the last move.
  void undo() {
    if (state == null || _currentMoveIndex < 0) return;

    _currentMoveIndex--;
    _reconstructState();
  }

  /// Redo the next move.
  void redo() {
    if (state == null || _currentMoveIndex >= _moveHistory.length - 1) return;

    _currentMoveIndex++;
    _reconstructState();
  }

  /// Check if undo is possible.
  bool get canUndo => state != null && _currentMoveIndex >= 0;

  /// Check if redo is possible.
  bool get canRedo => state != null && _currentMoveIndex < _moveHistory.length - 1;

  /// Get move history.
  List<GameMove> get moveHistory => List.unmodifiable(_moveHistory);

  /// Get current move index.
  int get currentMoveIndex => _currentMoveIndex;

  /// Reconstruct state from move history.
  void _reconstructState() {
    if (state == null) return;

    final engine = ref.read(engineProvider(state!.engineId));
    if (engine == null) return;
    final basePuzzle = _initialPuzzle ?? state!.puzzle;

    var currentPuzzle = basePuzzle;
    var isSolved = engine.isSolved(currentPuzzle.state);

    // Apply moves up to current index
    for (int i = 0; i <= _currentMoveIndex; i++) {
      final move = _moveHistory[i];
      final result = engine.validateMove(
        currentState: currentPuzzle.state,
        move: move.move,
      );

      if (result.isValid && result.newState != null) {
        currentPuzzle = GeneratedPuzzle(
          state: result.newState!,
          meta: currentPuzzle.meta,
          telemetry: currentPuzzle.telemetry,
        );
        isSolved = engine.isSolved(result.newState!);
      }
    }

    state = state!.copyWith(
      puzzle: currentPuzzle,
      isSolved: isSolved,
    );
  }

  /// Save game state to JSON.
  Map<String, dynamic> toJson() {
    if (state == null) return {};

    return {
      'gameState': state!.toJson(),
      'moveHistory': _moveHistory.map((move) => move.toJson()).toList(),
      'currentMoveIndex': _currentMoveIndex,
    };
  }

  /// Load game state from JSON.
  Future<void> loadFromJson(Map<String, dynamic> json) async {
    if (!json.containsKey('gameState')) return;

    final gameState = GameState.fromJson(json['gameState']);
    final moveHistory = (json['moveHistory'] as List?)
        ?.map((moveJson) => GameMove.fromJson(moveJson))
        .toList() ?? [];
    final currentMoveIndex = json['currentMoveIndex'] as int? ?? -1;

    _moveHistory.clear();
    _moveHistory.addAll(moveHistory);
    _currentMoveIndex = currentMoveIndex;
    _initialPuzzle = gameState.puzzle;

    state = gameState;
  }

  /// Parse difficulty string to DifficultyScore.
  DifficultyScore _parseDifficulty(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const DifficultyScore(value: 0.3, level: 'easy');
      case 'medium':
        return const DifficultyScore(value: 0.6, level: 'medium');
      case 'hard':
        return const DifficultyScore(value: 0.9, level: 'hard');
      default:
        return const DifficultyScore(value: 0.6, level: 'medium');
    }
  }

  /// Parse size string to SizeOpt.
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

  /// Request a gameplay hint from the engine for the current game state.
  ///
  /// Returns a [PuzzleHint] if the active engine supports hints and a hint
  /// could be produced, or `null` otherwise. This method is async to
  /// allow engines to perform any internal work (even though current
  /// implementations may be synchronous).
  Future<PuzzleHint?> requestHint({PuzzleHintRequest? request}) async {
    if (state == null) return null;

    final engine = ref.read(engineProvider(state!.engineId));
    if (engine == null) return null;

    // If engine advertises no hint capability, bail out early.
    if (!engine.capabilities.supportsHints) return null;

    try {
      final hint = engine.requestHint(
        currentState: state!.puzzle.state,
        request: request,
      );
      return hint;
    } catch (e) {
      // Swallow errors - hint is a best-effort feature.
      return null;
    }
  }

}

/// Game state containing puzzle and game information.
class GameState {
  final String engineId;
  final String seed;
  final String difficulty;
  final String size;
  final GeneratedPuzzle puzzle;
  final bool isSolved;
  final DateTime startTime;
  final DateTime? lastMoveTime;

  const GameState({
    required this.engineId,
    required this.seed,
    required this.difficulty,
    required this.size,
    required this.puzzle,
    required this.isSolved,
    required this.startTime,
    this.lastMoveTime,
  });

  GameState copyWith({
    String? engineId,
    String? seed,
    String? difficulty,
    String? size,
    GeneratedPuzzle? puzzle,
    bool? isSolved,
    DateTime? startTime,
    DateTime? lastMoveTime,
  }) {
    return GameState(
      engineId: engineId ?? this.engineId,
      seed: seed ?? this.seed,
      difficulty: difficulty ?? this.difficulty,
      size: size ?? this.size,
      puzzle: puzzle ?? this.puzzle,
      isSolved: isSolved ?? this.isSolved,
      startTime: startTime ?? this.startTime,
      lastMoveTime: lastMoveTime ?? this.lastMoveTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'engineId': engineId,
    'seed': seed,
    'difficulty': difficulty,
    'size': size,
    'puzzle': puzzle.toJson(),
    'isSolved': isSolved,
    'startTime': startTime.toIso8601String(),
    'lastMoveTime': lastMoveTime?.toIso8601String(),
  };

  factory GameState.fromJson(Map<String, dynamic> json) {
    // Note: This is a simplified version. In practice, you'd need
    // to properly deserialize the puzzle based on the engine type
    throw UnimplementedError('GameState.fromJson needs proper implementation');
  }
}

/// Record of a move made in the game.
class GameMove {
  final dynamic move;
  final DateTime timestamp;
  final int moveIndex;

  const GameMove({
    required this.move,
    required this.timestamp,
    required this.moveIndex,
  });

  Map<String, dynamic> toJson() => {
    'move': _moveToJson(move),
    'timestamp': timestamp.toIso8601String(),
    'moveIndex': moveIndex,
  };

  factory GameMove.fromJson(Map<String, dynamic> json) {
    // Note: This is a simplified version. In practice, you'd need
    // to properly deserialize the move based on the engine type
    throw UnimplementedError('GameMove.fromJson needs proper implementation');
  }

  /// Convert move to JSON (simplified).
  Map<String, dynamic> _moveToJson(dynamic move) {
    if (move is Map<String, dynamic>) {
      return move;
    }
    // Try to call toJson if the move has it
    try {
      return (move as dynamic).toJson() as Map<String, dynamic>;
    } catch (e) {
      return {'type': move.runtimeType.toString()};
    }
  }
}
