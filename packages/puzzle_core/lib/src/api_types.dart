/// Core API types for the puzzle engine system.
/// 
/// This file contains the stable, public API types that the app will use
/// to interact with puzzle engines. These types are designed to be
/// "boring and stable" - they don't leak engine internals.
library puzzle_core.api_types;

/// Abstract base class for puzzle engines.
/// 
/// [S] is the state type (e.g., SudokuBoard, CrosswordGrid)
/// [M] is the move type (e.g., SudokuMove, CrosswordMove)
abstract class PuzzleEngine<S, M> {
  /// Unique identifier for this engine type.
  String get id;
  
  /// Human-readable name for this engine.
  String get name;
  
  /// Version of this engine implementation.
  String get version;
  
  /// Generate a new puzzle with the given parameters.
  /// 
  /// Returns a [GeneratedPuzzle] with deterministic metadata
  /// based on the seed and parameters.
  GeneratedPuzzle<S> generate({
    required String seedStr,
    required int seed64,
    required SizeOpt size,
    required DifficultyScore difficulty,
  });
  
  /// Validate a move against the current puzzle state.
  /// 
  /// Returns a [MoveResult] indicating whether the move is valid
  /// and what the new state should be.
  MoveResult<S> validateMove({
    required S currentState,
    required M move,
  });
  
  /// Check if the puzzle is solved.
  bool isSolved(S state);
}

/// Registry for managing puzzle engines.
/// 
/// Allows registration and retrieval of engines by ID.
/// Prevents duplicate registrations.
class EngineRegistry {
  static final EngineRegistry _instance = EngineRegistry._internal();
  factory EngineRegistry() => _instance;
  EngineRegistry._internal();
  
  final Map<String, PuzzleEngine> _engines = {};
  
  /// Register a puzzle engine.
  /// 
  /// Throws [ArgumentError] if an engine with the same ID is already registered.
  void register<T, U>(PuzzleEngine<T, U> engine) {
    if (_engines.containsKey(engine.id)) {
      throw ArgumentError('Engine with ID "${engine.id}" is already registered');
    }
    _engines[engine.id] = engine;
  }
  
  /// Get an engine by ID.
  /// 
  /// Returns null if no engine with the given ID is registered.
  PuzzleEngine? getEngine(String id) => _engines[id];
  
  /// Get all registered engine IDs.
  List<String> get registeredIds => _engines.keys.toList();
  
  /// Clear all registered engines (mainly for testing).
  void clear() => _engines.clear();
  
  /// Get an engine by ID with type safety.
  /// 
  /// Returns null if no engine with the given ID is registered.
  /// The caller is responsible for casting to the correct type.
  T? getEngineAs<T>(String id) {
    final engine = getEngine(id);
    return engine as T?;
  }
  
  /// Check if an engine with the given ID is registered.
  bool hasEngine(String id) => _engines.containsKey(id);
  
  /// Get the number of registered engines.
  int get engineCount => _engines.length;
  
  /// Get all registered engines as a list.
  List<PuzzleEngine> get allEngines => _engines.values.toList();
  
  /// Get engines by type (if we had type information).
  /// This is a placeholder for future type-safe engine retrieval.
  List<PuzzleEngine> getEnginesByType(String type) {
    // For now, we don't have type information, so return all engines
    // In a real implementation, engines might register with type information
    return allEngines;
  }
}

/// A generated puzzle with metadata.
/// 
/// Contains the puzzle state and all metadata required for
/// deterministic generation and validation.
class GeneratedPuzzle<S> {
  /// The puzzle state/board.
  final S state;
  
  /// Metadata about the generation process.
  final PuzzleMetadata meta;
  
  const GeneratedPuzzle({
    required this.state,
    required this.meta,
  });
  
  /// Convert to JSON for serialization.
  Map<String, dynamic> toJson() => {
    'state': _stateToJson(state),
    'meta': meta.toJson(),
  };
  
  /// Create from JSON.
  factory GeneratedPuzzle.fromJson(
    Map<String, dynamic> json,
    S Function(Map<String, dynamic>) stateFromJson,
  ) => GeneratedPuzzle(
    state: stateFromJson(json['state'] as Map<String, dynamic>),
    meta: PuzzleMetadata.fromJson(json['meta'] as Map<String, dynamic>),
  );
  
  /// Convert state to JSON - to be implemented by specific puzzle types.
  Map<String, dynamic> _stateToJson(S state) {
    // Try to call toJson if the state has it
    if (state is Map<String, dynamic>) {
      return state;
    }
    // For stub states, try to call toJson method
    try {
      return (state as dynamic).toJson() as Map<String, dynamic>;
    } catch (e) {
      // Fallback to basic serialization
      return {'type': state.runtimeType.toString()};
    }
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneratedPuzzle &&
          runtimeType == other.runtimeType &&
          meta == other.meta;
  
  @override
  int get hashCode => meta.hashCode;
  
  @override
  String toString() => 'GeneratedPuzzle(meta: $meta)';
}

/// Metadata about puzzle generation.
/// 
/// Contains all information needed to reproduce a puzzle
/// deterministically.
class PuzzleMetadata {
  /// Version of the engine that generated this puzzle.
  final String engineVersion;
  
  /// ID of the RNG used for generation.
  final String rngId;
  
  /// Size configuration used.
  final SizeOpt size;
  
  /// Difficulty level used.
  final DifficultyScore difficulty;
  
  /// String seed used for generation.
  final String seedStr;
  
  /// 64-bit integer seed used for generation.
  final int seed64;
  
  const PuzzleMetadata({
    required this.engineVersion,
    required this.rngId,
    required this.size,
    required this.difficulty,
    required this.seedStr,
    required this.seed64,
  });
  
  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'engineVersion': engineVersion,
    'rngId': rngId,
    'size': size.toJson(),
    'difficulty': difficulty.toJson(),
    'seedStr': seedStr,
    'seed64': seed64,
  };
  
  /// Create from JSON.
  factory PuzzleMetadata.fromJson(Map<String, dynamic> json) => PuzzleMetadata(
    engineVersion: json['engineVersion'] as String,
    rngId: json['rngId'] as String,
    size: SizeOpt.fromJson(json['size'] as Map<String, dynamic>),
    difficulty: DifficultyScore.fromJson(json['difficulty'] as Map<String, dynamic>),
    seedStr: json['seedStr'] as String,
    seed64: json['seed64'] as int,
  );
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleMetadata &&
          runtimeType == other.runtimeType &&
          engineVersion == other.engineVersion &&
          rngId == other.rngId &&
          size == other.size &&
          difficulty == other.difficulty &&
          seedStr == other.seedStr &&
          seed64 == other.seed64;
  
  @override
  int get hashCode => Object.hash(
    engineVersion,
    rngId,
    size,
    difficulty,
    seedStr,
    seed64,
  );
  
  @override
  String toString() => 'PuzzleMetadata(engineVersion: $engineVersion, rngId: $rngId, seedStr: $seedStr)';
}

/// Result of validating a move.
/// 
/// Contains the new state after the move and validation information.
class MoveResult<S> {
  /// Whether the move was valid.
  final bool isValid;
  
  /// The new state after applying the move.
  final S? newState;
  
  /// Optional error message if the move was invalid.
  final String? errorMessage;
  
  const MoveResult({
    required this.isValid,
    this.newState,
    this.errorMessage,
  });
  
  /// Create a successful move result.
  factory MoveResult.success(S newState) => MoveResult(
    isValid: true,
    newState: newState,
  );
  
  /// Create a failed move result.
  factory MoveResult.failure(String errorMessage) => MoveResult(
    isValid: false,
    errorMessage: errorMessage,
  );
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          errorMessage == other.errorMessage;
  
  @override
  int get hashCode => Object.hash(isValid, errorMessage);
  
  @override
  String toString() => 'MoveResult(isValid: $isValid, errorMessage: $errorMessage)';
}

/// Result of puzzle validation.
/// 
/// Contains information about the validity of a puzzle state.
class ValidationResult {
  /// Whether the puzzle state is valid.
  final bool isValid;
  
  /// Optional error message if validation failed.
  final String? errorMessage;
  
  /// List of specific issues found during validation.
  final List<String> issues;
  
  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.issues = const [],
  });
  
  /// Create a successful validation result.
  factory ValidationResult.success() => const ValidationResult(isValid: true);
  
  /// Create a failed validation result.
  factory ValidationResult.failure(String errorMessage, [List<String> issues = const []]) => ValidationResult(
    isValid: false,
    errorMessage: errorMessage,
    issues: issues,
  );
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          errorMessage == other.errorMessage &&
          issues == other.issues;
  
  @override
  int get hashCode => Object.hash(isValid, errorMessage, issues);
  
  @override
  String toString() => 'ValidationResult(isValid: $isValid, errorMessage: $errorMessage)';
}

/// Difficulty score for puzzles.
/// 
/// Represents the difficulty level of a puzzle on a scale.
class DifficultyScore {
  /// The difficulty value (0.0 = easiest, 1.0 = hardest).
  final double value;
  
  /// Human-readable difficulty level.
  final String level;
  
  const DifficultyScore({
    required this.value,
    required this.level,
  });
  
  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'value': value,
    'level': level,
  };
  
  /// Create from JSON.
  factory DifficultyScore.fromJson(Map<String, dynamic> json) => DifficultyScore(
    value: (json['value'] as num).toDouble(),
    level: json['level'] as String,
  );
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DifficultyScore &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          level == other.level;
  
  @override
  int get hashCode => Object.hash(value, level);
  
  @override
  String toString() => 'DifficultyScore(value: $value, level: $level)';
}

/// Size options for puzzles.
/// 
/// Represents different size configurations for puzzles.
class SizeOpt {
  /// The size identifier.
  final String id;
  
  /// Human-readable size description.
  final String description;
  
  /// Width of the puzzle.
  final int width;
  
  /// Height of the puzzle.
  final int height;
  
  const SizeOpt({
    required this.id,
    required this.description,
    required this.width,
    required this.height,
  });
  
  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'width': width,
    'height': height,
  };
  
  /// Create from JSON.
  factory SizeOpt.fromJson(Map<String, dynamic> json) => SizeOpt(
    id: json['id'] as String,
    description: json['description'] as String,
    width: json['width'] as int,
    height: json['height'] as int,
  );
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeOpt &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          description == other.description &&
          width == other.width &&
          height == other.height;
  
  @override
  int get hashCode => Object.hash(id, description, width, height);
  
  @override
  String toString() => 'SizeOpt(id: $id, description: $description, ${width}x$height)';
}

/// Minimal RNG facade for deterministic generation.
/// 
/// This is a placeholder interface for the RNG system.
/// Full implementation will be added in later phases.
abstract class SeededRng {
  /// Create a new RNG with the given seed.
  factory SeededRng(int seed64) => _SimpleRng(seed64);
  
  /// Generate the next random integer.
  int nextInt();
  
  /// Generate a random integer in the range [0, max).
  int nextIntInRange(int max);
  
  /// Generate a random double in the range [0.0, 1.0).
  double nextDouble();
}

/// Simple RNG implementation for testing.
/// 
/// This is a minimal implementation that provides deterministic
/// behavior for testing purposes.
class _SimpleRng implements SeededRng {
  int _state;
  
  _SimpleRng(int seed) : _state = seed;
  
  @override
  int nextInt() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state;
  }
  
  @override
  int nextIntInRange(int max) {
    if (max <= 0) return 0;
    return nextInt() % max;
  }
  
  @override
  double nextDouble() {
    return nextInt() / 0x7fffffff;
  }
}
