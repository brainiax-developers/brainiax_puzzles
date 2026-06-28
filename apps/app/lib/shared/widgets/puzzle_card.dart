import 'package:flutter/material.dart';

import '../models/models.dart';
import 'brainiax/brainiax_widgets.dart';

class PuzzleCard extends StatelessWidget {
  const PuzzleCard({
    super.key,
    required this.metadata,
    required this.isFavourite,
    required this.isInProgress,
    this.onTap,
    required this.onToggleFavourite,
    this.onResume,
  });

  final PuzzleMetadata metadata;
  final bool isFavourite;
  final bool isInProgress;
  final VoidCallback? onTap;
  final VoidCallback onToggleFavourite;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color accentColor = metadata.primaryAccentColor;
    final bool isUnavailable = !metadata.isAvailable;
    final Color mutedColor = colorScheme.onSurfaceVariant;

    return BrainiaxCard(
      emphasized: isInProgress,
      onTap: isUnavailable ? null : onTap,
      borderRadius: 24,
      child: Opacity(
        opacity: isUnavailable ? 0.55 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PuzzleIconBadge(metadata: metadata, size: 60, borderRadius: 18),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          metadata.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isUnavailable ? mutedColor : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: isFavourite
                            ? 'Remove favourite'
                            : 'Add favourite',
                        onPressed: onToggleFavourite,
                        icon: Icon(
                          isFavourite ? Icons.star : Icons.star_outline,
                          color: isFavourite ? Colors.amber[700] : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LibraryInfoPill(
                        label: _categoryLabelFor(metadata.type),
                        backgroundColor: isUnavailable
                            ? colorScheme.surfaceContainerHighest
                            : accentColor.withValues(alpha: 0.14),
                        foregroundColor: isUnavailable
                            ? mutedColor
                            : accentColor,
                      ),
                      if (metadata.availabilityBadgeLabel != null)
                        _LibraryInfoPill(
                          label: metadata.availabilityBadgeLabel!,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          foregroundColor: mutedColor,
                        ),
                      if (isInProgress)
                        _LibraryInfoPill(
                          label: 'In Progress',
                          backgroundColor: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                        ),
                      if (onResume != null && !isUnavailable)
                        Tooltip(
                          message: 'Resume saved game',
                          child: ActionChip(
                            avatar: const Icon(
                              Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: const Text('Continue'),
                            onPressed: onResume,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    metadata.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                  if (metadata.unavailableMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      metadata.unavailableMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: metadata.supportedDifficulties.map((difficulty) {
                      return DifficultyChip(label: difficulty, readOnly: true);
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _categoryLabelFor(PuzzleType puzzleType) {
  switch (puzzleType) {
    case PuzzleType.sudokuClassic:
    case PuzzleType.kakuro:
    case PuzzleType.mathdokuClassic:
    case PuzzleType.takuzuBinary:
      return 'Numbers';
    case PuzzleType.nonogramMono:
    case PuzzleType.slitherlinkLoop:
    case PuzzleType.killerQueens:
      return 'Visual';
  }
}

class _LibraryInfoPill extends StatelessWidget {
  const _LibraryInfoPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
