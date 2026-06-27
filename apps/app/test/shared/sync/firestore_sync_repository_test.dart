import 'package:app/shared/sync/firestore_sync_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

      expect(
        result.favouriteKeys,
        <String>['nonogram_mono', 'sudoku_classic'],
      );
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
