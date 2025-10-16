/// Stub engines for testing and validation.
///
/// These engines provide deterministic implementations wired through the
/// pipeline template so that tests exercise the generator → solver → validator
/// → difficulty flow without requiring full puzzle logic.
library puzzle_core.stub_engine;

import '../api_types.dart';
import '../difficulty/difficulty_config.dart';
import '../difficulty/telemetry.dart';
import '../engine/pipeline_engine.dart';
import '../generators/generator.dart';
import '../solver/solver.dart';
import '../util/determinism.dart';
import '../validation/validator.dart';

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

class _StubGenerator extends PuzzleGenerator<StubPuzzleState> {
  const _StubGenerator();

  @override
  PuzzleGenerationResult<StubPuzzleState> generate(GeneratorContext context) {
    final stopwatch = Stopwatch()..start();
    final List<int> randomValues = <int>[];
    for (int i = 0; i < context.size.width; i++) {
      randomValues.add(context.rng.nextIntInRange(1024));
    }
    final data = <String, dynamic>{
      'seed': context.seed64,
      'size': {'w': context.size.width, 'h': context.size.height},
      'requestedDifficulty': context.difficulty.level,
      'random_values': randomValues,
      'hint': context.difficulty.hint,
    };
    stopwatch.stop();
    return PuzzleGenerationResult(
      board: StubPuzzleState(
        id: 'stub-${context.seed64}-${context.size.id}-${context.difficulty.level}',
        data: data,
      ),
      snapshot: GenerationSnapshot(
        telemetry: {
          'durationMs': stopwatch.elapsedMicroseconds / 1000.0,
          'xor': randomValues.fold<int>(0, (acc, value) => acc ^ value),
        },
      ),
    );
  }
}

class _StubSolver extends PuzzleSolver<StubPuzzleState> {
  const _StubSolver();

  @override
  SolverResult<StubPuzzleState> solve(
    StubPuzzleState board,
    SolverContext context,
  ) {
    final stopwatch = Stopwatch()..start();
    final Map<String, dynamic> solvedData = Map<String, dynamic>.from(board.data);
    solvedData['solved'] = true;
    solvedData['solution_signature'] = _deriveSignature(board.data);
    stopwatch.stop();

    final result = StubPuzzleState(id: board.id, data: solvedData);
    final telemetry = <String, Object?>{
      'maxSolutions': context.maxSolutions,
      'signature': solvedData['solution_signature'],
      'elapsedUs': stopwatch.elapsedMicroseconds,
    };

    return SolverResult<StubPuzzleState>(
      solutions: <StubPuzzleState>[result],
      elapsed: stopwatch.elapsed,
      telemetry: telemetry,
    );
  }

  int _deriveSignature(Map<String, dynamic> data) {
    final values = (data['random_values'] as List?)?.cast<int>() ?? const <int>[];
    int hash = 17;
    for (final value in values) {
      hash = (hash * 31) ^ value;
    }
    return hash & 0xffffffff;
  }
}

class _StubValidator extends PuzzleValidator<StubPuzzleState> {
  const _StubValidator();

  @override
  ValidationSummary validatePuzzle(StubPuzzleState board) {
    final stopwatch = Stopwatch()..start();
    final issues = <String>[];
    if (!board.data.containsKey('random_values')) {
      issues.add('missing_random_values');
    }
    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  ValidationSummary validateSolution(
    StubPuzzleState board,
    StubPuzzleState solution,
  ) {
    final stopwatch = Stopwatch()..start();
    final issues = <String>[];
    if (board.id != solution.id) {
      issues.add('id_mismatch');
    }
    if (solution.data['solved'] != true) {
      issues.add('not_solved');
    }
    final boardValues = board.data['random_values'] as List? ?? const [];
    final solutionValues = solution.data['random_values'] as List? ?? const [];
    if (boardValues.length != solutionValues.length) {
      issues.add('value_length_mismatch');
    }
    stopwatch.stop();
    return issues.isEmpty
        ? ValidationSummary.success(stopwatch.elapsed)
        : ValidationSummary.failure(stopwatch.elapsed, issues);
  }

  @override
  bool isSolved(StubPuzzleState board) => board.data['solved'] == true;
}

class _StubDifficultyScorer extends DifficultyScorer<StubPuzzleState> {
  const _StubDifficultyScorer();

  @override
  DifficultyTelemetry score({
    required StubPuzzleState puzzle,
    required StubPuzzleState solution,
    required DifficultyContext context,
  }) {
    final values = (puzzle.data['random_values'] as List?)?.cast<int>() ?? const <int>[];
    final double entropy = values.isEmpty
        ? 0
        : values.fold<int>(0, (acc, value) => acc ^ value).toDouble() /
            (values.length * 1024.0);
    final Map<String, num> metrics = {
      'width': (puzzle.data['size'] as Map)['w'] as num,
      'height': (puzzle.data['size'] as Map)['h'] as num,
      'entropy': entropy,
      'generatorDurationMs':
          (context.generatorTelemetry['durationMs'] as num?)?.toDouble() ?? 0.0,
    };
    final double rawScore = (metrics['entropy']! + 0.1).clamp(0.0, 1.0);
    return DifficultyTelemetry(
      rawScore: rawScore,
      bucket: 'pending',
      metrics: metrics,
    );
  }
}

DifficultyBucketConfig _createDefaultDifficultyConfig() {
  return const DifficultyBucketConfig(
    buckets: [
      DifficultyBucketThreshold(
        id: 'easy',
        maxInclusive: 0.4,
      ),
      DifficultyBucketThreshold(
        id: 'medium',
        maxInclusive: 0.7,
      ),
      DifficultyBucketThreshold(
        id: 'hard',
        maxInclusive: 1.0,
      ),
    ],
  );
}

class StubPuzzleEngine extends PipelinePuzzleEngine<StubPuzzleState, StubPuzzleMove> {
  StubPuzzleEngine({
    DifficultyBucketConfig? config,
    String engineId = 'stub',
    String engineName = 'Stub Puzzle Engine',
    String engineVersion = '2.0.0',
  }) : super(
          engineId: engineId,
          engineName: engineName,
          engineVersion: engineVersion,
          generator: const _StubGenerator(),
          solver: const _StubSolver(),
          validator: const _StubValidator(),
          difficultyScorer: const _StubDifficultyScorer(),
          difficultyConfig: config ?? _createDefaultDifficultyConfig(),
        );

  @override
  MoveResult<StubPuzzleState> validateMove({
    required StubPuzzleState currentState,
    required StubPuzzleMove move,
  }) {
    if (move.type == 'invalid') {
      return MoveResult.failure('Invalid move type');
    }

    final newData = Map<String, dynamic>.from(currentState.data);
    newData['last_move'] = move.toJson();
    newData['move_count'] = (newData['move_count'] ?? 0) + 1;

    final newState = StubPuzzleState(
      id: currentState.id,
      data: newData,
    );

    DeterminismGuard.assertNoFloatsOrDateTimes(newState.data);

    return MoveResult.success(newState);
  }
}

class StubSudokuEngine extends StubPuzzleEngine {
  StubSudokuEngine({DifficultyBucketConfig? config})
      : super(
          config: config,
          engineId: 'stub_sudoku',
          engineName: 'Stub Sudoku Engine',
        );
}
