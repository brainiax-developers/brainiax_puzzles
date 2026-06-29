/// Core API types for the puzzle engine system.
/// 
/// This file contains the stable, public API types that the app will use
/// to interact with puzzle engines. These types are designed to be
/// "boring and stable" - they don't leak engine internals.
library;

import 'dart:collection';

import 'difficulty/telemetry.dart';

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

  /// Capabilities exposed by this engine implementation.
  ///
  /// Engines can override this getter to advertise support for optional
  /// features. By default, engines opt out of all capabilities to maintain
  /// backwards compatibility.
  PuzzleCapabilities get capabilities => const PuzzleCapabilities();

  /// Request a hint for the current puzzle state.
  ///
  /// Engines that support hints should override this method and return a
  /// [PuzzleHint] describing the affected cells or units. Implementations
  /// must remain deterministic given the same [PuzzleHintRequest].
  ///
  /// Engines that do not support hints may rely on the default implementation
  /// which returns `null`.
  PuzzleHint? requestHint({
    required S currentState,
    PuzzleHintRequest? request,
  }) =>
      null;
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

  /// Optional telemetry captured during generation.
  final GenerationTelemetry? telemetry;

  const GeneratedPuzzle({
    required this.state,
    required this.meta,
    this.telemetry,
  });

  /// Convert to JSON for serialization.
  Map<String, dynamic> toJson() => {
        'state': _stateToJson(state),
        'meta': meta.toJson(),
        if (telemetry != null) 'telemetry': telemetry!.toJson(),
      };

  /// Create from JSON.
  factory GeneratedPuzzle.fromJson(
    Map<String, dynamic> json,
    S Function(Map<String, dynamic>) stateFromJson,
  ) =>
      GeneratedPuzzle(
        state: stateFromJson(json['state'] as Map<String, dynamic>),
        meta: PuzzleMetadata.fromJson(json['meta'] as Map<String, dynamic>),
        telemetry: json.containsKey('telemetry')
            ? GenerationTelemetry.fromJson(
                Map<String, dynamic>.from(json['telemetry'] as Map),
              )
            : null,
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
          meta == other.meta &&
          telemetry == other.telemetry;

  @override
  int get hashCode => Object.hash(meta, telemetry);

  @override
  String toString() => 'GeneratedPuzzle(meta: $meta, telemetry: $telemetry)';
}

/// Advertised capabilities for a puzzle engine.
class PuzzleCapabilities {
  const PuzzleCapabilities({
    this.supportsHints = false,
  });

  /// Whether this engine can provide gameplay hints.
  final bool supportsHints;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleCapabilities &&
          runtimeType == other.runtimeType &&
          supportsHints == other.supportsHints;

  @override
  int get hashCode => supportsHints.hashCode;
}

/// Parameters describing a hint request.
class PuzzleHintRequest {
  const PuzzleHintRequest({
    this.seed64,
    this.iteration = 0,
    this.moveCount,
    this.metadata = const <String, Object?>{},
  });

  /// Optional deterministic seed to use when deriving the hint.
  final int? seed64;

  /// Sequence number for multiple hint requests within the same session.
  final int iteration;

  /// Optional current move count when the hint was requested.
  final int? moveCount;

  /// Additional metadata contextualising the request.
  final Map<String, Object?> metadata;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleHintRequest &&
          runtimeType == other.runtimeType &&
          seed64 == other.seed64 &&
          iteration == other.iteration &&
          moveCount == other.moveCount &&
          _deepEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
        seed64,
        iteration,
        moveCount,
        _deepHash(metadata),
      );
}

/// Highlight information returned from [PuzzleEngine.requestHint].
class PuzzleHint {
  PuzzleHint({
    List<PuzzleHintCell> cells = const <PuzzleHintCell>[],
    List<PuzzleHintUnit> units = const <PuzzleHintUnit>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  })  : cells = UnmodifiableListView<PuzzleHintCell>(
            List<PuzzleHintCell>.from(cells)),
        units = UnmodifiableListView<PuzzleHintUnit>(
            List<PuzzleHintUnit>.from(units)),
        metadata = Map.unmodifiable(Map<String, Object?>.from(metadata));

  /// Highlighted cells in row/column space.
  final UnmodifiableListView<PuzzleHintCell> cells;

  /// Highlighted logical units such as rows, columns, or boxes.
  final UnmodifiableListView<PuzzleHintUnit> units;

  /// Arbitrary metadata describing the hint.
  final Map<String, Object?> metadata;

  /// Whether the hint contains no highlight information.
  bool get isEmpty => cells.isEmpty && units.isEmpty && metadata.isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleHint &&
          runtimeType == other.runtimeType &&
          _deepEquals(cells, other.cells) &&
          _deepEquals(units, other.units) &&
          _deepEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
        _deepHash(cells),
        _deepHash(units),
        _deepHash(metadata),
      );
}

/// A single cell highlighted by a hint.
class PuzzleHintCell {
  PuzzleHintCell({
    required this.row,
    required this.column,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map.unmodifiable(Map<String, Object?>.from(metadata));

  /// Row coordinate of the highlighted cell.
  final int row;

  /// Column coordinate of the highlighted cell.
  final int column;

  /// Additional metadata describing the cell highlight.
  final Map<String, Object?> metadata;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleHintCell &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          column == other.column &&
          _deepEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(row, column, _deepHash(metadata));
}

/// A logical unit (row, column, box, etc.) highlighted by a hint.
class PuzzleHintUnit {
  PuzzleHintUnit({
    required this.type,
    required this.index,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = Map.unmodifiable(Map<String, Object?>.from(metadata));

  /// Identifier for the unit type (e.g. `row`, `column`, `box`).
  final String type;

  /// Index within the given unit type.
  final int index;

  /// Additional metadata describing the unit highlight.
  final Map<String, Object?> metadata;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PuzzleHintUnit &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          index == other.index &&
          _deepEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(type, index, _deepHash(metadata));
}

class GenerationTelemetry {
  final DifficultyTelemetry difficulty;
  final Map<String, Object?> extras;

  const GenerationTelemetry({
    required this.difficulty,
    this.extras = const <String, Object?>{},
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'difficulty': difficulty.toJson(),
        'extras': extras,
      };

  factory GenerationTelemetry.fromJson(Map<String, dynamic> json) =>
      GenerationTelemetry(
        difficulty: DifficultyTelemetry.fromJson(
          Map<String, dynamic>.from(json['difficulty'] as Map),
        ),
        extras: Map<String, Object?>.from(json['extras'] as Map? ?? const {}),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerationTelemetry &&
          runtimeType == other.runtimeType &&
          difficulty.rawScore == other.difficulty.rawScore &&
          difficulty.bucket == other.difficulty.bucket &&
          _deepEquals(extras, other.extras);

  @override
  int get hashCode => Object.hash(
        difficulty.rawScore,
        difficulty.bucket,
        _deepHash(extras),
      );
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) {
      return false;
    }
    for (final key in a.keys) {
      if (!b.containsKey(key)) {
        return false;
      }
      if (!_deepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  if (a is Iterable && b is Iterable) {
    final ita = a.iterator;
    final itb = b.iterator;
    while (true) {
      final hasA = ita.moveNext();
      final hasB = itb.moveNext();
      if (hasA != hasB) {
        return false;
      }
      if (!hasA) {
        return true;
      }
      if (!_deepEquals(ita.current, itb.current)) {
        return false;
      }
    }
  }
  return a == b;
}

int _deepHash(Object? value) {
  if (value is Map) {
    int hash = 0;
    for (final entry in value.entries) {
      hash = Object.hash(hash, entry.key, _deepHash(entry.value));
    }
    return hash;
  }
  if (value is Iterable) {
    return Object.hashAll(value.map(_deepHash));
  }
  return value.hashCode;
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
