import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/shared/models/puzzle_type.dart';
import 'package:app/shared/services/puzzle_telemetry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late PuzzleTelemetryService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    service = SharedPreferencesPuzzleTelemetryService(prefs);
  });

  test('records telemetry events with correct counts', () async {
    await service.recordStarted(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      seed: 'seed-1',
      timestamp: DateTime.utc(2024, 1, 1, 12),
    );

    await service.recordHintUsed(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      seed: 'seed-1',
      timestamp: DateTime.utc(2024, 1, 1, 12, 1),
    );

    await service.recordHintUsed(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      seed: 'seed-1',
      timestamp: DateTime.utc(2024, 1, 1, 12, 2),
    );

    await service.recordSolved(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      seed: 'seed-1',
      duration: const Duration(minutes: 5),
      timestamp: DateTime.utc(2024, 1, 1, 12, 10),
    );

    await service.recordDailyCompleted(
      puzzleType: PuzzleType.sudokuClassic,
      difficulty: 'easy',
      seed: 'seed-1',
      duration: const Duration(minutes: 5),
      timestamp: DateTime.utc(2024, 1, 1, 12, 15),
    );

    final events = await service.events();

    expect(
      events.where((event) => event.type == PuzzleTelemetryEventType.started).length,
      1,
    );
    expect(
      events.where((event) => event.type == PuzzleTelemetryEventType.hintUsed).length,
      2,
    );
    expect(
      events.where((event) => event.type == PuzzleTelemetryEventType.solved).length,
      1,
    );
    expect(
      events
          .where((event) => event.type == PuzzleTelemetryEventType.dailyCompleted)
          .length,
      1,
    );
  });

  test('queue survives service recreation', () async {
    await service.recordStarted(
      puzzleType: PuzzleType.kakuroClassic,
      difficulty: 'medium',
      seed: 'seed-xyz',
      timestamp: DateTime.utc(2024, 6, 1, 8),
    );

    await service.recordSolved(
      puzzleType: PuzzleType.kakuroClassic,
      difficulty: 'medium',
      seed: 'seed-xyz',
      duration: const Duration(minutes: 7),
      timestamp: DateTime.utc(2024, 6, 1, 8, 20),
    );

    final storedQueue = List<String>.from(
      prefs.getStringList(SharedPreferencesPuzzleTelemetryService.queueKey) ??
          const <String>[],
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesPuzzleTelemetryService.queueKey: storedQueue,
    });

    final SharedPreferences newPrefs = await SharedPreferences.getInstance();
    final newService = SharedPreferencesPuzzleTelemetryService(newPrefs);

    final events = await newService.events();

    expect(events.length, 2);
    expect(
      events.where((event) => event.type == PuzzleTelemetryEventType.solved).length,
      1,
    );
  });
}
