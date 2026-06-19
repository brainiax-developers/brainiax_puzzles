import 'package:flutter/material.dart';
import 'puzzle_type.dart';
import 'puzzle_category.dart';

/// Metadata for a puzzle type including UI properties and capabilities.
class PuzzleMetadata {
  const PuzzleMetadata({
    required this.type,
    required this.displayName,
    required this.description,
    required this.icon,
    required this.accentColors,
    required this.supportedSizes,
    required this.supportedDifficulties,
    required this.supportsHints,
    required this.category,
  });

  /// The puzzle type this metadata describes.
  final PuzzleType type;

  /// Human-readable display name.
  final String displayName;

  /// Short objective or summary shown in selection UI.
  final String description;

  /// Icon placeholder (can be replaced with actual icon later).
  final IconData icon;

  /// Accent colors for the puzzle type.
  final List<Color> accentColors;

  /// Supported puzzle sizes.
  final List<String> supportedSizes;

  /// Supported difficulty levels.
  final List<String> supportedDifficulties;

  /// Whether this puzzle type supports hints.
  final bool supportsHints;

  /// The category this puzzle belongs to.
  final PuzzleCategory category;

  /// Get the primary accent color.
  Color get primaryAccentColor => accentColors.isNotEmpty ? accentColors.first : Colors.blue;

  /// Get the secondary accent color.
  Color get secondaryAccentColor => accentColors.length > 1 ? accentColors[1] : primaryAccentColor;
}
