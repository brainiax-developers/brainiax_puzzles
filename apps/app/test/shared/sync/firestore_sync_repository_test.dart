import 'package:app/shared/app_metadata/app_metadata.dart';
import 'package:app/shared/models/models.dart';
import 'package:app/shared/stats/puzzle_run_result.dart';
import 'package:app/shared/sync/firestore_sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds completed run upload metadata without gameplay payloads', () {
    final result = PuzzleRunResult(
      id: 'run-1',
      puzzleType: PuzzleType.sudokuClassic,
      mode: PuzzleMode.daily,
      difficulty: 'hard',
      size: '9x9',
      seed: 'seed-123',
      completedAtUtc: DateTime.utc(2026, 6, 21, 12, 5),
      elapsedMs: 300000,
      moveCount: 45,
      hintsUsed: 1,
      dailyDateKeyUtc: '2026-06-21',
      engineVersion: 'engine-1',
      startedAtUtc: DateTime.utc(2026, 6, 21, 12),
      sessionUpdatedAtUtc: DateTime.utc(2026, 6, 21, 12, 4),
    );

    final model = runResultFirestoreModelForUpload(
      uid: 'uid-123',
      result: result,
      appMetadata: const AppBuildMetadata(appVersion: '1.0.0+1'),
      createdAtUtc: DateTime.utc(2026, 6, 21, 12, 6),
      updatedAtUtc: DateTime.utc(2026, 6, 21, 12, 7),
    );
    final json = model.toFirestoreJson();

    expect(model.runId, 'run-1');
    expect(model.uid, 'uid-123');
    expect(model.seed, 'seed-123');
    expect(model.completed, isTrue);
    expect(model.engineVersion, 'engine-1');
    expect(model.appVersion, '1.0.0+1');
    expect(model.createdAtUtc, DateTime.utc(2026, 6, 21, 12, 6));
    expect(model.updatedAtUtc, DateTime.utc(2026, 6, 21, 12, 7));
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

  test(
    'run upload metadata falls back for missing optional version fields',
    () {
      final result = PuzzleRunResult(
        id: 'run-1',
        puzzleType: PuzzleType.sudokuClassic,
        mode: PuzzleMode.random,
        difficulty: 'easy',
        size: '9x9',
        seed: 'seed-123',
        completedAtUtc: DateTime.utc(2026, 6, 21, 12, 5),
        elapsedMs: 300000,
        moveCount: 45,
        hintsUsed: 1,
        dailyDateKeyUtc: null,
        engineVersion: '',
      );

      final model = runResultFirestoreModelForUpload(
        uid: 'uid-123',
        result: result,
        appMetadata: const AppBuildMetadata(
          defaultEngineVersion: 'engine-fallback',
        ),
        createdAtUtc: DateTime.utc(2026, 6, 21, 12, 6),
        updatedAtUtc: DateTime.utc(2026, 6, 21, 12, 7),
      );

      expect(model.engineVersion, 'engine-fallback');
      expect(model.appVersion, unknownAppMetadataValue);
      expect(model.startedAtUtc, DateTime.utc(2026, 6, 21, 12));
      expect(model.sessionUpdatedAtUtc, DateTime.utc(2026, 6, 21, 12, 5));
    },
  );

  group('resolveFavouritePreferencesForSync', () {
    test('uses local favourites when cloud preferences are empty', () {
      final result = resolveFavouritePreferencesForSync(
        remotePreferences: const <String, dynamic>{},
        localFavouriteKeys: const <String>['sudoku_classic'],
        localUpdatedAtUtc: DateTime.utc(2026, 6, 21, 12),
      );

      expect(result.favouriteKeys, <String>['sudoku_classic']);
      expect(result.updatedAtUtc, DateTime.utc(2026, 6, 21, 12));
    });

    test('uses union on first merge when cloud timestamp is missing', () {
      final result = resolveFavouritePreferencesForSync(
        remotePreferences: const <String, dynamic>{
          'favoritePuzzleTypes': <String>['nonogram_mono'],
        },
        localFavouriteKeys: const <String>['sudoku_classic'],
        localUpdatedAtUtc: DateTime.utc(2026, 6, 21, 12),
      );

      expect(result.favouriteKeys, <String>['nonogram_mono', 'sudoku_classic']);
      expect(result.updatedAtUtc, DateTime.utc(2026, 6, 21, 12));
    });

    test('keeps remote favourites when remote timestamp is newer', () {
      final result = resolveFavouritePreferencesForSync(
        remotePreferences: <String, dynamic>{
          'favoritePuzzleTypes': const <String>['nonogram_mono'],
          'updatedAt': DateTime.utc(2026, 6, 21, 13),
        },
        localFavouriteKeys: const <String>['sudoku_classic'],
        localUpdatedAtUtc: DateTime.utc(2026, 6, 21, 12),
      );

      expect(result.favouriteKeys, <String>['nonogram_mono']);
      expect(result.updatedAtUtc, DateTime.utc(2026, 6, 21, 13));
    });

    test('uses local favourites when local timestamp is newer', () {
      final result = resolveFavouritePreferencesForSync(
        remotePreferences: <String, dynamic>{
          'favoritePuzzleTypes': const <String>['nonogram_mono'],
          'updatedAt': DateTime.utc(2026, 6, 21, 12),
        },
        localFavouriteKeys: const <String>['sudoku_classic'],
        localUpdatedAtUtc: DateTime.utc(2026, 6, 21, 13),
      );

      expect(result.favouriteKeys, <String>['sudoku_classic']);
      expect(result.updatedAtUtc, DateTime.utc(2026, 6, 21, 13));
    });
  });
}
