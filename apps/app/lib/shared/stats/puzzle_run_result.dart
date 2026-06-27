import '../app_metadata/app_metadata.dart';
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
    this.engineVersion = unknownAppMetadataValue,
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
  final String engineVersion;
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
      engineVersion: _engineVersionFromSession(session),
      startedAtUtc:
          startedAtUtc?.toUtc() ??
          session?.createdAtUtc.toUtc() ??
          record.completedAtUtc.toUtc().subtract(
            Duration(milliseconds: record.elapsedMs),
          ),
      sessionUpdatedAtUtc:
          sessionUpdatedAtUtc?.toUtc() ??
          session?.updatedAtUtc.toUtc() ??
          record.completedAtUtc.toUtc(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'puzzleType': puzzleType.key,
    'mode': mode.key,
    'difficulty': difficulty,
    'size': size,
    'seed': seed,
    'completed': completed,
    'completedAtUtc': completedAtUtc.toUtc().toIso8601String(),
    'elapsedMs': elapsedMs,
    'moveCount': moveCount,
    'hintsUsed': hintsUsed,
    'dailyDateKeyUtc': dailyDateKeyUtc,
    'engineVersion': engineVersion,
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

    final DateTime completedAtUtc = DateTime.parse(
      json['completedAtUtc'] as String,
    ).toUtc();
    final int elapsedMs = json['elapsedMs'] as int? ?? 0;

    return PuzzleRunResult(
      id: json['id'] as String,
      puzzleType: puzzleType,
      mode: mode,
      difficulty: json['difficulty'] as String? ?? 'unknown',
      size: json['size'] as String? ?? 'unknown',
      seed: json['seed'] as String? ?? '',
      completedAtUtc: completedAtUtc,
      elapsedMs: elapsedMs,
      moveCount: json['moveCount'] as int? ?? 0,
      hintsUsed: json['hintsUsed'] as int? ?? 0,
      dailyDateKeyUtc: json['dailyDateKeyUtc'] as String?,
      engineVersion:
          json['engineVersion'] as String? ?? unknownAppMetadataValue,
      startedAtUtc:
          _dateTimeOrNull(json['startedAtUtc']) ??
          completedAtUtc.subtract(Duration(milliseconds: elapsedMs)),
      sessionUpdatedAtUtc:
          _dateTimeOrNull(json['sessionUpdatedAtUtc']) ?? completedAtUtc,
    );
  }
}

String _engineVersionFromSession(ActivePuzzleRun? session) {
  final Object? meta = session?.generatedPuzzleJson['meta'];
  if (meta is! Map) {
    return unknownAppMetadataValue;
  }
  final Object? engineVersion = meta['engineVersion'];
  if (engineVersion is! String || engineVersion.trim().isEmpty) {
    return unknownAppMetadataValue;
  }
  return engineVersion;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  return null;
}
