import 'package:flutter/material.dart';

/// Categories for organizing puzzle types.
enum PuzzleCategory {
  logic('Logic', 'Puzzles that require logical reasoning and deduction'),
  word('Word', 'Puzzles involving words, letters, and language');

  const PuzzleCategory(this.displayName, this.description);

  /// Human-readable display name for the category.
  final String displayName;

  /// Description of the category.
  final String description;

  /// Get the icon for this category.
  IconData get icon {
    switch (this) {
      case PuzzleCategory.logic:
        return Icons.psychology;
      case PuzzleCategory.word:
        return Icons.text_fields;
    }
  }

  /// Get the primary color for this category.
  Color get primaryColor {
    switch (this) {
      case PuzzleCategory.logic:
        return const Color(0xFF2196F3); // Blue
      case PuzzleCategory.word:
        return const Color(0xFF4CAF50); // Green
    }
  }

  /// Get the secondary color for this category.
  Color get secondaryColor {
    switch (this) {
      case PuzzleCategory.logic:
        return const Color(0xFF1976D2); // Darker blue
      case PuzzleCategory.word:
        return const Color(0xFF388E3C); // Darker green
    }
  }
}
