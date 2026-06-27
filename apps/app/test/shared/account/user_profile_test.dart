import 'package:app/shared/account/user_profile.dart';
import 'package:app/shared/models/puzzle_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('round-trips through JSON', () {
      final profile = UserProfile(
        uid: 'user-123',
        createdAtUtc: DateTime.utc(2024, 1, 2, 3, 4, 5),
        lastSeenAtUtc: DateTime.utc(2024, 2, 3, 4, 5, 6),
        displayName: 'Ada Lovelace',
        isAnonymous: false,
        providerIds: const <String>['password', 'google.com'],
        schemaVersion: 2,
        preferences: UserPreferences(
          favouritePuzzleTypes: const <PuzzleType>[
            PuzzleType.sudokuClassic,
            PuzzleType.nonogramMono,
          ],
          favouritesUpdatedAtUtc: DateTime.utc(2024, 2, 4, 5, 6, 7),
        ),
      );

      final restored = UserProfile.fromJson(profile.toJson());

      expect(restored.uid, profile.uid);
      expect(restored.createdAtUtc, profile.createdAtUtc);
      expect(restored.lastSeenAtUtc, profile.lastSeenAtUtc);
      expect(restored.displayName, profile.displayName);
      expect(restored.isAnonymous, profile.isAnonymous);
      expect(restored.providerIds, profile.providerIds);
      expect(restored.schemaVersion, profile.schemaVersion);
      expect(
        restored.preferences.favouritePuzzleTypes,
        profile.preferences.favouritePuzzleTypes,
      );
      expect(
        restored.preferences.favouritesUpdatedAtUtc,
        profile.preferences.favouritesUpdatedAtUtc,
      );
    });

    test('applies defaults when optional fields are missing', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'uid': 'new-user',
        'createdAtUtc': '2024-01-02T03:04:05.000Z',
      });

      expect(profile.uid, 'new-user');
      expect(profile.createdAtUtc, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(profile.lastSeenAtUtc, isNull);
      expect(profile.displayName, isNull);
      expect(profile.isAnonymous, isFalse);
      expect(profile.providerIds, isEmpty);
      expect(profile.schemaVersion, 1);
      expect(profile.preferences.favouritePuzzleTypes, isEmpty);
      expect(profile.preferences.favouritesUpdatedAtUtc, isNull);
    });

    test('accepts legacy aliases and coerces common scalar shapes', () {
      final profile = UserProfile.fromJson(<String, dynamic>{
        'uid': 'legacy-user',
        'createdAt': '2023-11-12T13:14:15Z',
        'lastSeenAtUtc': 1700000000000,
        'displayName': 'Legacy User',
        'isAnonymous': 'true',
        'providerIds': 'google.com',
        'schemaVersion': '3',
        'favouritePuzzleTypes': <Object?>[
          'sudoku_classic',
          'invalid_type',
          PuzzleType.takuzuBinary,
        ],
        'favouritesUpdatedAtUtc': '2024-02-03T04:05:06Z',
      });

      expect(profile.uid, 'legacy-user');
      expect(profile.createdAtUtc, DateTime.utc(2023, 11, 12, 13, 14, 15));
      expect(
        profile.lastSeenAtUtc,
        DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
      );
      expect(profile.displayName, 'Legacy User');
      expect(profile.isAnonymous, isTrue);
      expect(profile.providerIds, <String>['google.com']);
      expect(profile.schemaVersion, 3);
      expect(profile.preferences.favouritePuzzleTypes, <PuzzleType>[
        PuzzleType.sudokuClassic,
        PuzzleType.takuzuBinary,
      ]);
      expect(
        profile.preferences.favouritesUpdatedAtUtc,
        DateTime.utc(2024, 2, 3, 4, 5, 6),
      );
    });

    test('rejects malformed required fields and ignores bad list entries', () {
      final preferences = UserPreferences.fromJson(<String, dynamic>{
        'favouritePuzzleTypes': <Object?>[
          'sudoku_classic',
          42,
          'still_not_real',
        ],
      });

      expect(preferences.favouritePuzzleTypes, <PuzzleType>[
        PuzzleType.sudokuClassic,
      ]);

      expect(
        () => UserProfile.fromJson(<String, dynamic>{
          'uid': 'broken-user',
          'createdAtUtc': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });
}
