import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/puzzle_mode.dart';

void main() {
  group('PuzzleMode', () {
    test('should have correct key and display name for daily', () {
      expect(PuzzleMode.daily.key, equals('daily'));
      expect(PuzzleMode.daily.displayName, equals('Daily Challenge'));
    });

    test('should have correct key and display name for random', () {
      expect(PuzzleMode.random.key, equals('random'));
      expect(PuzzleMode.random.displayName, equals('Random Puzzle'));
    });

    group('fromKey', () {
      test('should return correct PuzzleMode for valid keys', () {
        expect(PuzzleMode.fromKey('daily'), equals(PuzzleMode.daily));
        expect(PuzzleMode.fromKey('random'), equals(PuzzleMode.random));
      });

      test('should return null for invalid keys', () {
        expect(PuzzleMode.fromKey('invalid_key'), isNull);
        expect(PuzzleMode.fromKey(''), isNull);
        expect(PuzzleMode.fromKey('challenge'), isNull);
      });
    });

    group('isValidKey', () {
      test('should return true for valid keys', () {
        expect(PuzzleMode.isValidKey('daily'), isTrue);
        expect(PuzzleMode.isValidKey('random'), isTrue);
      });

      test('should return false for invalid keys', () {
        expect(PuzzleMode.isValidKey('invalid_key'), isFalse);
        expect(PuzzleMode.isValidKey(''), isFalse);
        expect(PuzzleMode.isValidKey('challenge'), isFalse);
      });
    });

    test('toString should return the key', () {
      expect(PuzzleMode.daily.toString(), equals('daily'));
      expect(PuzzleMode.random.toString(), equals('random'));
    });
  });
}
