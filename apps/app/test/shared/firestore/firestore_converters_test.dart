import 'package:app/shared/firestore/firestore_converters.dart';
import 'package:app/shared/firestore/firestore_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firestore converters', () {
    test('round-trips user profile metadata', () {
      final model = UserProfileFirestoreModel(
        uid: 'uid-123',
        createdAtUtc: DateTime.utc(2026, 6, 20, 8),
        lastSeenAtUtc: DateTime.utc(2026, 6, 21, 9),
        displayName: 'Ada',
        isAnonymous: true,
        providerIds: const <String>['anonymous'],
        preferences: UserPreferencesFirestoreModel(
          favoritePuzzleTypes: const <String>['sudoku_classic'],
          preferredDifficulties: const <String, String>{
            'sudoku_classic': 'hard',
          },
          updatedAtUtc: DateTime.utc(2026, 6, 22, 10),
        ),
      );

      final json = userProfileFirestoreConverter.toJson(model);
      final restored = userProfileFirestoreConverter.fromJson(json);

      expect(json['schemaVersion'], firestoreSchemaVersion);
      expect(json['createdAt'], isA<Timestamp>());
      expect(restored.uid, model.uid);
      expect(restored.createdAtUtc, model.createdAtUtc);
      expect(restored.lastSeenAtUtc, model.lastSeenAtUtc);
      expect(restored.displayName, model.displayName);
      expect(restored.isAnonymous, isTrue);
      expect(restored.providerIds, model.providerIds);
      expect(
        restored.preferences.favoritePuzzleTypes,
        model.preferences.favoritePuzzleTypes,
      );
      expect(
        restored.preferences.preferredDifficulties,
        model.preferences.preferredDifficulties,
      );
      expect(restored.preferences.updatedAtUtc, model.preferences.updatedAtUtc);
    });

    test('round-trips run result metadata without board payloads', () {
      final model = RunResultFirestoreModel(
        runId: 'run-1',
        uid: 'uid-123',
        puzzleType: 'sudoku_classic',
        mode: 'daily',
        seed: 'seed-123',
        difficulty: 'hard',
        size: '9x9',
        completed: true,
        dailyDateKeyUtc: '2026-06-20',
        startedAtUtc: DateTime.utc(2026, 6, 20, 8),
        completedAtUtc: DateTime.utc(2026, 6, 20, 8, 5),
        sessionUpdatedAtUtc: DateTime.utc(2026, 6, 20, 8, 4),
        elapsedMs: 300000,
        moveCount: 45,
        hintsUsed: 1,
        engineVersion: '1.0.0',
        appVersion: '1.0.0+1',
        createdAtUtc: DateTime.utc(2026, 6, 20, 8, 6),
        updatedAtUtc: DateTime.utc(2026, 6, 20, 8, 7),
      );

      final json = runResultFirestoreConverter.toJson(model);
      final restored = runResultFirestoreConverter.fromJson(json);

      expect(json['schemaVersion'], firestoreSchemaVersion);
      expect(json['completedAt'], isA<Timestamp>());
      expect(restored.runId, model.runId);
      expect(restored.uid, model.uid);
      expect(restored.puzzleType, model.puzzleType);
      expect(restored.mode, model.mode);
      expect(restored.seed, model.seed);
      expect(restored.completed, isTrue);
      expect(restored.dailyDateKeyUtc, model.dailyDateKeyUtc);
      expect(restored.startedAtUtc, model.startedAtUtc);
      expect(restored.completedAtUtc, model.completedAtUtc);
      expect(restored.elapsedMs, model.elapsedMs);
      expect(restored.moveCount, model.moveCount);
      expect(restored.hintsUsed, model.hintsUsed);
      expect(restored.engineVersion, model.engineVersion);
      expect(restored.appVersion, model.appVersion);
      expect(restored.createdAtUtc, model.createdAtUtc);
      expect(restored.updatedAtUtc, model.updatedAtUtc);
      expect(json['seed'], 'seed-123');
      expect(json['completed'], isTrue);
      expect(json['engineVersion'], '1.0.0');
      expect(json['appVersion'], '1.0.0+1');
      expect(json['createdAt'], isA<Timestamp>());
      expect(json['updatedAt'], isA<Timestamp>());
      expect(
        json.keys.toSet().intersection(<String>{
          'board',
          'cells',
          'grid',
          'generatedPuzzleJson',
          'solution',
          'activeRunState',
          'moves',
        }),
        isEmpty,
      );
    });

    test('round-trips stats aggregate metadata', () {
      final model = StatsAggregateFirestoreModel(
        uid: 'uid-123',
        puzzleType: 'nonogram_mono',
        totalCompletions: 3,
        randomCompletions: 2,
        dailyCompletions: 1,
        totalElapsedMs: 900000,
        totalMoveCount: 120,
        totalHintsUsed: 4,
        bestElapsedMs: 240000,
        firstCompletedAtUtc: DateTime.utc(2026, 6, 18),
        lastCompletedAtUtc: DateTime.utc(2026, 6, 20),
        byDifficulty: <String, StatsBreakdownFirestoreModel>{
          'hard': StatsBreakdownFirestoreModel(
            totalCompletions: 1,
            randomCompletions: 0,
            dailyCompletions: 1,
            totalElapsedMs: 240000,
            totalMoveCount: 30,
            totalHintsUsed: 0,
            bestElapsedMs: 240000,
            firstCompletedAtUtc: DateTime.utc(2026, 6, 20),
            lastCompletedAtUtc: DateTime.utc(2026, 6, 20),
          ),
        },
      );

      final json = statsAggregateFirestoreConverter.toJson(model);
      final restored = statsAggregateFirestoreConverter.fromJson(json);

      expect(json['schemaVersion'], firestoreSchemaVersion);
      expect(restored.uid, model.uid);
      expect(restored.puzzleType, model.puzzleType);
      expect(restored.totalCompletions, model.totalCompletions);
      expect(restored.bestElapsedMs, model.bestElapsedMs);
      expect(restored.firstCompletedAtUtc, model.firstCompletedAtUtc);
      expect(restored.byDifficulty['hard']?.dailyCompletions, 1);
      expect(restored.byDifficulty['hard']?.bestElapsedMs, 240000);
    });

    test('round-trips daily streak state metadata', () {
      final model = DailyStreakStateFirestoreModel(
        uid: 'uid-123',
        currentStreak: 5,
        bestStreak: 7,
        lastCompletedDateKeyUtc: '2026-06-20',
        updatedAtUtc: DateTime.utc(2026, 6, 20, 12),
      );

      final json = dailyStreakStateFirestoreConverter.toJson(model);
      final restored = dailyStreakStateFirestoreConverter.fromJson(json);

      expect(json['schemaVersion'], firestoreSchemaVersion);
      expect(restored.uid, model.uid);
      expect(restored.currentStreak, model.currentStreak);
      expect(restored.bestStreak, model.bestStreak);
      expect(restored.lastCompletedDateKeyUtc, model.lastCompletedDateKeyUtc);
      expect(restored.updatedAtUtc, model.updatedAtUtc);
    });

    test('round-trips leaderboard entry and app config metadata', () {
      final entry = LeaderboardEntryFirestoreModel(
        entryId: 'entry-1',
        periodId: '2026-06',
        puzzleType: 'takuzu_binary',
        uid: 'uid-123',
        displayName: 'Ada',
        score: 1000,
        rank: 2,
        elapsedMs: 180000,
        moveCount: 22,
        hintsUsed: 0,
        difficulty: 'medium',
        size: '8x8',
        completedAtUtc: DateTime.utc(2026, 6, 20, 8),
        updatedAtUtc: DateTime.utc(2026, 6, 20, 9),
      );
      final config = AppConfigFirestoreModel(
        cloudSyncEnabled: true,
        leaderboardsEnabled: true,
        minSupportedSchemaVersion: 1,
        updatedAtUtc: DateTime.utc(2026, 6, 20),
      );

      final entryJson = leaderboardEntryFirestoreConverter.toJson(entry);
      final configJson = appConfigFirestoreConverter.toJson(config);
      final restoredEntry = leaderboardEntryFirestoreConverter.fromJson(
        entryJson,
      );
      final restoredConfig = appConfigFirestoreConverter.fromJson(configJson);

      expect(entryJson['schemaVersion'], firestoreSchemaVersion);
      expect(restoredEntry.entryId, entry.entryId);
      expect(restoredEntry.periodId, entry.periodId);
      expect(restoredEntry.puzzleType, entry.puzzleType);
      expect(restoredEntry.completedAtUtc, entry.completedAtUtc);
      expect(configJson['schemaVersion'], firestoreSchemaVersion);
      expect(restoredConfig.cloudSyncEnabled, isTrue);
      expect(restoredConfig.leaderboardsEnabled, isTrue);
      expect(restoredConfig.updatedAtUtc, config.updatedAtUtc);
    });

    test('requires Timestamp-compatible date values', () {
      expect(
        () => RunResultFirestoreModel.fromFirestoreJson(<String, dynamic>{
          'schemaVersion': 1,
          'runId': 'run-1',
          'uid': 'uid-123',
          'puzzleType': 'sudoku_classic',
          'mode': 'random',
          'seed': 'seed-123',
          'difficulty': 'easy',
          'size': '9x9',
          'completed': true,
          'startedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 20, 7, 59)),
          'completedAt': '2026-06-20T08:00:00Z',
          'elapsedMs': 1,
          'moveCount': 1,
          'hintsUsed': 0,
          'engineVersion': '1.0.0',
          'appVersion': '1.0.0+1',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 20, 8)),
          'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 20, 8)),
        }),
        throwsFormatException,
      );
    });
  });
}
