import 'puzzle_mode.dart';
import 'puzzle_type.dart';

/// Persisted state for an in-progress puzzle.
class ActivePuzzleRun {
  const ActivePuzzleRun({
    required this.puzzleType,
    required this.mode,
    required this.difficulty,
    required this.size,
    required this.seed,
    required this.generatedPuzzleJson,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.elapsedMs,
    required this.moveCount,
    required this.hintsUsed,
    required this.isSolved,
    required this.dailyDateKeyUtc,
  });

  final PuzzleType puzzleType;
  final PuzzleMode mode;
  final String difficulty;
  final String size;
  final String seed;
  final Map<String, dynamic> generatedPuzzleJson;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final int elapsedMs;
  final int moveCount;
  final int hintsUsed;
  final bool isSolved;
  final String? dailyDateKeyUtc;

  ActivePuzzleRun copyWith({
    PuzzleMode? mode,
    String? difficulty,
    String? size,
    String? seed,
    Map<String, dynamic>? generatedPuzzleJson,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    int? elapsedMs,
    int? moveCount,
    int? hintsUsed,
    bool? isSolved,
    String? dailyDateKeyUtc,
  }) {
    return ActivePuzzleRun(
      puzzleType: puzzleType,
      mode: mode ?? this.mode,
      difficulty: difficulty ?? this.difficulty,
      size: size ?? this.size,
      seed: seed ?? this.seed,
      generatedPuzzleJson: generatedPuzzleJson ?? this.generatedPuzzleJson,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      moveCount: moveCount ?? this.moveCount,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      isSolved: isSolved ?? this.isSolved,
      dailyDateKeyUtc: dailyDateKeyUtc ?? this.dailyDateKeyUtc,
    );
  }

  Map<String, dynamic> toJson() => {
    'puzzleType': puzzleType.key,
    'mode': mode.key,
    'difficulty': difficulty,
    'size': size,
    'seed': seed,
    'generatedPuzzleJson': generatedPuzzleJson,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
    'elapsedMs': elapsedMs,
    'moveCount': moveCount,
    'hintsUsed': hintsUsed,
    'isSolved': isSolved,
    'dailyDateKeyUtc': dailyDateKeyUtc,
  };

  factory ActivePuzzleRun.fromJson(Map<String, dynamic> json) {
    final PuzzleType? puzzleType = PuzzleType.fromKey(
      json['puzzleType'] as String? ?? '',
    );
    final PuzzleMode? mode = PuzzleMode.fromKey(json['mode'] as String? ?? '');
    if (puzzleType == null || mode == null) {
      throw FormatException('Invalid active run type or mode: $json');
    }
    return ActivePuzzleRun(
      puzzleType: puzzleType,
      mode: mode,
      difficulty: json['difficulty'] as String? ?? 'medium',
      size: json['size'] as String? ?? 'unknown',
      seed: json['seed'] as String? ?? '',
      generatedPuzzleJson: Map<String, dynamic>.from(
        json['generatedPuzzleJson'] as Map,
      ),
      createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toUtc(),
      updatedAtUtc: DateTime.parse(json['updatedAtUtc'] as String).toUtc(),
      elapsedMs: json['elapsedMs'] as int? ?? 0,
      moveCount: json['moveCount'] as int? ?? 0,
      hintsUsed: json['hintsUsed'] as int? ?? 0,
      isSolved: json['isSolved'] as bool? ?? false,
      dailyDateKeyUtc: json['dailyDateKeyUtc'] as String?,
    );
  }
}
