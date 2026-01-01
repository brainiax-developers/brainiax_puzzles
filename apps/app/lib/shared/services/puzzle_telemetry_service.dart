import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle_type.dart';

/// Telemetry events that can be recorded for puzzle interactions.
enum PuzzleTelemetryEventType {
  started('started'),
  solved('solved'),
  hintUsed('hint_used'),
  dailyCompleted('daily_completed');

  const PuzzleTelemetryEventType(this.key);

  final String key;

  static PuzzleTelemetryEventType fromKey(String key) {
    return PuzzleTelemetryEventType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => throw ArgumentError.value(
        key,
        'key',
        'Unknown telemetry event type',
      ),
    );
  }
}

/// Telemetry event payload.
class PuzzleTelemetryEvent {
  PuzzleTelemetryEvent({
    required this.type,
    required this.timestamp,
    required this.puzzleType,
    required this.difficulty,
    required this.seed,
    this.duration,
  });

  factory PuzzleTelemetryEvent.fromJson(Map<String, Object?> json) {
    final String typeKey = json['event'] as String;
    final String puzzleTypeKey = json['puzzleType'] as String;
    return PuzzleTelemetryEvent(
      type: PuzzleTelemetryEventType.fromKey(typeKey),
      timestamp: DateTime.parse(json['timestamp'] as String),
      puzzleType:
          PuzzleType.fromKey(puzzleTypeKey) ?? PuzzleType.sudokuClassic,
      difficulty: json['difficulty'] as String,
      seed: json['seed'] as String,
      duration: (json['durationMs'] as int?) != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
    );
  }

  final PuzzleTelemetryEventType type;
  final DateTime timestamp;
  final PuzzleType puzzleType;
  final String difficulty;
  final String seed;
  final Duration? duration;

  Map<String, Object?> toJson() => <String, Object?>{
        'event': type.key,
        'timestamp': timestamp.toIso8601String(),
        'puzzleType': puzzleType.key,
        'difficulty': difficulty,
        'seed': seed,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
      };
}

/// Contract for collecting puzzle telemetry events.
abstract class PuzzleTelemetryService {
  Future<void> recordStarted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    DateTime? timestamp,
  });

  Future<void> recordSolved({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    required Duration duration,
    DateTime? timestamp,
  });

  Future<void> recordHintUsed({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    DateTime? timestamp,
  });

  Future<void> recordDailyCompleted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    required Duration duration,
    DateTime? timestamp,
  });

  Future<List<PuzzleTelemetryEvent>> events();

  Future<void> flush();
}

/// SharedPreferences-backed telemetry service that stores events in an
/// append-only queue for later delivery.
class SharedPreferencesPuzzleTelemetryService
    implements PuzzleTelemetryService {
  SharedPreferencesPuzzleTelemetryService(this._prefs);

  final SharedPreferences _prefs;

  static const storageNamespace = 'puzzle_telemetry_service.v1';

  static const queueKey = '$storageNamespace.queue';

  @override
  Future<void> recordStarted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    DateTime? timestamp,
  }) async {
    final event = PuzzleTelemetryEvent(
      type: PuzzleTelemetryEventType.started,
      timestamp: timestamp ?? DateTime.now(),
      puzzleType: puzzleType,
      difficulty: difficulty,
      seed: seed,
    );
    await _appendEvent(event);
  }

  @override
  Future<void> recordSolved({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    required Duration duration,
    DateTime? timestamp,
  }) async {
    final event = PuzzleTelemetryEvent(
      type: PuzzleTelemetryEventType.solved,
      timestamp: timestamp ?? DateTime.now(),
      puzzleType: puzzleType,
      difficulty: difficulty,
      seed: seed,
      duration: duration,
    );
    await _appendEvent(event);
  }

  @override
  Future<void> recordHintUsed({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    DateTime? timestamp,
  }) async {
    final event = PuzzleTelemetryEvent(
      type: PuzzleTelemetryEventType.hintUsed,
      timestamp: timestamp ?? DateTime.now(),
      puzzleType: puzzleType,
      difficulty: difficulty,
      seed: seed,
    );
    await _appendEvent(event);
  }

  @override
  Future<void> recordDailyCompleted({
    required PuzzleType puzzleType,
    required String difficulty,
    required String seed,
    required Duration duration,
    DateTime? timestamp,
  }) async {
    final event = PuzzleTelemetryEvent(
      type: PuzzleTelemetryEventType.dailyCompleted,
      timestamp: timestamp ?? DateTime.now(),
      puzzleType: puzzleType,
      difficulty: difficulty,
      seed: seed,
      duration: duration,
    );
    await _appendEvent(event);
  }

  @override
  Future<List<PuzzleTelemetryEvent>> events() async {
    final List<String> serialized =
        List<String>.from(_prefs.getStringList(queueKey) ?? const <String>[]);
    return serialized
        .map((entry) =>
            PuzzleTelemetryEvent.fromJson(json.decode(entry) as Map<String, Object?>))
        .toList(growable: false);
  }

  @override
  Future<void> flush() async {
    // Phase 4: Delivery is disabled, so flush is a no-op.
  }

  Future<void> _appendEvent(PuzzleTelemetryEvent event) async {
    final List<String> serialized =
        List<String>.from(_prefs.getStringList(queueKey) ?? const <String>[]);
    serialized.add(json.encode(event.toJson()));
    await _prefs.setStringList(queueKey, serialized);
  }
}
