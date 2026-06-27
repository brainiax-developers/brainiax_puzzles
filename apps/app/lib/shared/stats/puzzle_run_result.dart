import '../models/active_puzzle_run.dart';
import '../models/puzzle_completion_record.dart';
import '../models/puzzle_mode.dart';
import '../models/puzzle_type.dart';

/// Sync-safe DTO representing one completed puzzle run.
class PuzzleRunResult {
  const PuzzleRunResult({
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
    this.startedAtUtc,
    this.sessionUpdatedAtUtc,
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
  final DateTime? startedAtUtc;
  final DateTime? sessionUpdatedAtUtc;

  String get localRunId => id;

  bool get completed => true;

  bool get isDaily => mode == PuzzleMode.daily;

  bool get isRandom => mode == PuzzleMode.random;

  int get moves => moveCount;

  DateTime? get startedAt => startedAtUtc;

  DateTime get completedAt => completedAtUtc;

  factory PuzzleRunResult.fromCompletionRecord(
    PuzzleCompletionRecord record, {
    ActivePuzzleRun? session,
    DateTime? startedAtUtc,
    DateTime? sessionUpdatedAtUtc,
  }) {
    return PuzzleRunResult(
      id: record.id,
      puzzleType: record.puzzleType,
      mode: record.mode,
      difficulty: record.difficulty,
      size: record.size,
      seed: record.seed,
      completedAtUtc: record.completedAtUtc.toUtc(),
      elapsedMs: record.elapsedMs,
      moveCount: record.moveCount,
      hintsUsed: record.hintsUsed,
      dailyDateKeyUtc: record.dailyDateKeyUtc,
      startedAtUtc: startedAtUtc?.toUtc() ?? session?.createdAtUtc.toUtc(),
      sessionUpdatedAtUtc:
          sessionUpdatedAtUtc?.toUtc() ?? session?.updatedAtUtc.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
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
    'startedAtUtc': startedAtUtc?.toUtc().toIso8601String(),
    'sessionUpdatedAtUtc': sessionUpdatedAtUtc?.toUtc().toIso8601String(),
  };

  factory PuzzleRunResult.fromJson(Map<String, dynamic> json) {
    final PuzzleType? puzzleType = PuzzleType.fromKey(
      json['puzzleType'] as String? ?? '',
    );
    final PuzzleMode? mode = PuzzleMode.fromKey(json['mode'] as String? ?? '');
    if (puzzleType == null || mode == null) {
      throw FormatException('Invalid run result type or mode: $json');
    }

    return PuzzleRunResult(
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
      startedAtUtc: _dateTimeOrNull(json['startedAtUtc']),
      sessionUpdatedAtUtc: _dateTimeOrNull(json['sessionUpdatedAtUtc']),
    );
  }
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  return null;
}
