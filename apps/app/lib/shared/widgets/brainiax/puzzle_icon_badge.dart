import 'package:flutter/material.dart';

import '../../models/models.dart';

class PuzzleIconBadge extends StatelessWidget {
  const PuzzleIconBadge({
    super.key,
    this.puzzleType,
    this.metadata,
    this.icon,
    this.accentColor,
    this.size = 48,
    this.borderRadius = 16,
  });

  final PuzzleType? puzzleType;
  final PuzzleMetadata? metadata;
  final IconData? icon;
  final Color? accentColor;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color resolvedAccentColor =
        accentColor ??
        metadata?.primaryAccentColor ??
        _defaultAccentForPuzzleType(puzzleType, theme.colorScheme);
    final IconData resolvedIcon =
        icon ?? metadata?.icon ?? _defaultIconForPuzzleType(puzzleType);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolvedAccentColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(resolvedIcon, color: resolvedAccentColor),
    );
  }
}

IconData _defaultIconForPuzzleType(PuzzleType? puzzleType) {
  switch (puzzleType) {
    case PuzzleType.sudokuClassic:
      return Icons.grid_on;
    case PuzzleType.nonogramMono:
      return Icons.crop_square;

    case PuzzleType.slitherlinkLoop:
      return Icons.circle_outlined;
    case PuzzleType.mathdokuClassic:
      return Icons.calculate;
    case PuzzleType.killerQueens:
      return Icons.catching_pokemon;
    case PuzzleType.takuzuBinary:
      return Icons.code;
    case null:
      return Icons.extension_outlined;
  }
}

Color _defaultAccentForPuzzleType(
  PuzzleType? puzzleType,
  ColorScheme colorScheme,
) {
  switch (puzzleType) {
    case PuzzleType.sudokuClassic:
      return const Color(0xFF2196F3);
    case PuzzleType.nonogramMono:
      return const Color(0xFF4CAF50);

    case PuzzleType.slitherlinkLoop:
      return const Color(0xFF9C27B0);
    case PuzzleType.mathdokuClassic:
      return const Color(0xFFE91E63);
    case PuzzleType.killerQueens:
      return const Color(0xFF26C6DA);
    case PuzzleType.takuzuBinary:
      return const Color(0xFF607D8B);
    case null:
      return colorScheme.primary;
  }
}
