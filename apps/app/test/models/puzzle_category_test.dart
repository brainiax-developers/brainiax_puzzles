import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/shared/models/puzzle_category.dart';

void main() {
  group('PuzzleCategory', () {
    test('should have correct properties for logic category', () {
      expect(PuzzleCategory.logic.displayName, equals('Logic'));
      expect(PuzzleCategory.logic.description, equals('Puzzles that require logical reasoning and deduction'));
      expect(PuzzleCategory.logic.icon, equals(Icons.psychology));
    });

    test('should have correct properties for word category', () {
      expect(PuzzleCategory.word.displayName, equals('Word'));
      expect(PuzzleCategory.word.description, equals('Puzzles involving words, letters, and language'));
      expect(PuzzleCategory.word.icon, equals(Icons.text_fields));
    });

    test('should have correct colors for logic category', () {
      expect(PuzzleCategory.logic.primaryColor, equals(const Color(0xFF2196F3)));
      expect(PuzzleCategory.logic.secondaryColor, equals(const Color(0xFF1976D2)));
    });

    test('should have correct colors for word category', () {
      expect(PuzzleCategory.word.primaryColor, equals(const Color(0xFF4CAF50)));
      expect(PuzzleCategory.word.secondaryColor, equals(const Color(0xFF388E3C)));
    });
  });
}
