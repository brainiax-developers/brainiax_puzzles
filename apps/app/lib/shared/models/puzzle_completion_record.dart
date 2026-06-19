import 'puzzle_mode.dart';
import 'puzzle_type.dart';

/// Durable local record for a solved puzzle.
class PuzzleCompletionRecord {
  const PuzzleCompletionRecord({
    required this.id,
    required this.puzzleType,
    required this.mode,
    required this.difficulty,
    required this.size,
    required this.seed,
    required this.completedAtUtc,
    required this.elapsedMs,
    required this.moveCount,
    required this.hintsUsed,
    required this.dailyDateKeyUtc,
  });

  final String id;
  final PuzzleType puzzleType;
  final PuzzleMode mode;
  final String difficulty;
  final String size;
  final String seed;
  final DateTime completedAtUtc;
  final int elapsedMs;
  final int moveCount;
  final int hintsUsed;
  final String? dailyDateKeyUtc;

  Map<String, dynamic> toJson() => {
    'id': id,
    'puzzleType': puzzleType.key,
    'mode': mode.key,
    'difficulty': difficulty,
    'size': size,
    'seed': seed,
    'completedAtUtc': completedAtUtc.toUtc().toIso8601String(),
    'elapsedMs': elapsedMs,
    'moveCount': moveCount,
    'hintsUsed': hintsUsed,
    'dailyDateKeyUtc': dailyDateKeyUtc,
  };

  factory PuzzleCompletionRecord.fromJson(Map<String, dynamic> json) {
    final PuzzleType? puzzleType = PuzzleType.fromKey(
      json['puzzleType'] as String? ?? '',
    );
    final PuzzleMode? mode = PuzzleMode.fromKey(json['mode'] as String? ?? '');
    if (puzzleType == null || mode == null) {
      throw FormatException('Invalid completion record type or mode: $json');
    }
    return PuzzleCompletionRecord(
      id: json['id'] as String,
      puzzleType: puzzleType,
      mode: mode,
      difficulty: json['difficulty'] as String? ?? 'unknown',
      size: json['size'] as String? ?? 'unknown',
      seed: json['seed'] as String? ?? '',
      completedAtUtc: DateTime.parse(json['completedAtUtc'] as String).toUtc(),
      elapsedMs: json['elapsedMs'] as int? ?? 0,
      moveCount: json['moveCount'] as int? ?? 0,
      hintsUsed: json['hintsUsed'] as int? ?? 0,
      dailyDateKeyUtc: json['dailyDateKeyUtc'] as String?,
    );
  }
}
