import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/puzzle_type.dart';

void main() {
  group('PuzzleType', () {
    test('should have correct key and display name for sudoku_classic', () {
      expect(PuzzleType.sudokuClassic.key, equals('sudoku_classic'));
      expect(PuzzleType.sudokuClassic.displayName, equals('Classic Sudoku'));
    });

    test('should have correct key and display name for nonogram_mono', () {
      expect(PuzzleType.nonogramMono.key, equals('nonogram_mono'));
      expect(
        PuzzleType.nonogramMono.displayName,
        equals('Monochrome Nonogram'),
      );
    });



    test('should have correct key and display name for slitherlink_loop', () {
      expect(PuzzleType.slitherlinkLoop.key, equals('slitherlink_loop'));
      expect(
        PuzzleType.slitherlinkLoop.displayName,
        equals('Slitherlink Loop'),
      );
    });

    test('should have correct key and display name for mathdoku_classic', () {
      expect(PuzzleType.mathdokuClassic.key, equals('mathdoku_classic'));
      expect(
        PuzzleType.mathdokuClassic.displayName,
        equals('Classic Mathdoku'),
      );
    });

    test('should have correct key and display name for killer_queens', () {
      expect(PuzzleType.killerQueens.key, equals('killer_queens'));
      expect(PuzzleType.killerQueens.displayName, equals('Killer Queens'));
    });

    test('should have correct key and display name for takuzu_binary', () {
      expect(PuzzleType.takuzuBinary.key, equals('takuzu_binary'));
      expect(PuzzleType.takuzuBinary.displayName, equals('Binary Takuzu'));
    });

    group('fromKey', () {
      test('should return correct PuzzleType for valid keys', () {
        expect(
          PuzzleType.fromKey('sudoku_classic'),
          equals(PuzzleType.sudokuClassic),
        );
        expect(
          PuzzleType.fromKey('nonogram_mono'),
          equals(PuzzleType.nonogramMono),
        );

        expect(
          PuzzleType.fromKey('slitherlink_loop'),
          equals(PuzzleType.slitherlinkLoop),
        );
        expect(
          PuzzleType.fromKey('mathdoku_classic'),
          equals(PuzzleType.mathdokuClassic),
        );
        expect(
          PuzzleType.fromKey('killer_queens'),
          equals(PuzzleType.killerQueens),
        );
        expect(
          PuzzleType.fromKey('takuzu_binary'),
          equals(PuzzleType.takuzuBinary),
        );
      });

      test('should return null for invalid keys', () {
        expect(PuzzleType.fromKey('invalid_key'), isNull);
        expect(PuzzleType.fromKey(''), isNull);
        expect(PuzzleType.fromKey('sudoku'), isNull);
      });
    });

    group('isValidKey', () {
      test('should return true for valid keys', () {
        expect(PuzzleType.isValidKey('sudoku_classic'), isTrue);
        expect(PuzzleType.isValidKey('nonogram_mono'), isTrue);

        expect(PuzzleType.isValidKey('slitherlink_loop'), isTrue);
        expect(PuzzleType.isValidKey('mathdoku_classic'), isTrue);
        expect(PuzzleType.isValidKey('killer_queens'), isTrue);
        expect(PuzzleType.isValidKey('takuzu_binary'), isTrue);
      });

      test('should return false for invalid keys', () {
        expect(PuzzleType.isValidKey('invalid_key'), isFalse);
        expect(PuzzleType.isValidKey(''), isFalse);
        expect(PuzzleType.isValidKey('sudoku'), isFalse);
      });
    });

    test('toString should return the key', () {
      expect(PuzzleType.sudokuClassic.toString(), equals('sudoku_classic'));
      expect(PuzzleType.nonogramMono.toString(), equals('nonogram_mono'));
    });

    test('daily challenge roster includes slitherlink and killer queens', () {
      expect(
        PuzzleType.dailyChallengeTypes,
        contains(PuzzleType.slitherlinkLoop),
      );
      expect(PuzzleType.dailyChallengeTypes, contains(PuzzleType.killerQueens));
      expect(PuzzleType.slitherlinkLoop.isDailyEligible, isTrue);
      expect(PuzzleType.killerQueens.isDailyEligible, isTrue);
    });
  });
}
